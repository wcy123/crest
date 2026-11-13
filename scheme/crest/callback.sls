#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest callback) — C function pointers made from Scheme procedures.
;;
;;   (crest-make-static-c-callable (argument-type ...) result-type proc)   an address
;;   (crest-callback-pointer-list pointer count)                           a list of integers
;;   (crest-callback-entry-dispatcher entries)                             a procedure
;;
;; C++ never makes, owns, locks or releases a callback. A binding that needs one takes a plain C
;; function pointer; Scheme makes the foreign-callable (locked, because the garbage collector moves
;; code objects) and whoever calls the low-level function decides how long it lives. The C function
;; has the prototype that C++ or MLIR declares: its argument types and its RESULT TYPE are written at
;; every site (uptr, int, unsigned-8, void, walk-result, ...; the kinds are listed at %%make-code), and a mismatch crashes, as C++ does not check it.
;;
;; The procedure never raises into C++. MLIR's prototypes have no room for an error, so the guard of the
;; callable catches it and reports "<file>:<line>:<column>: <who>: <why>": result void ends the process with
;; that text (llvm::report_fatal_error); any other result calls mlir::emitError with it, in
;; (current-MLIRContext), and answers the zero of the C result type (with no current context the process ends
;; with the text). Scheme code that calls C++ sets the context with with-current-MLIRContext; a tool that
;; C++ drives (crest-opt) gets it from the C++ code that runs Scheme for a context (lib/Crest/CurrentContext.h).
;;
;;   crest-make-static-c-callable   locks it for good: only for a callback made once, at the library
;;                                  level, that uses no state of a run.
;;   with-c-callable                locks it for the body and unlocks it after, also on an error. The
;;                                  value is a procedure, or a locked code object or the address of a
;;                                  locked callable that the caller made (reused, never unlocked here).
;;   with-c-callables               the same for several, nested in order.
;;
;; The conversion clauses (with-TypeConverter, with-ConversionTarget, with-RewritePatternSet) use
;; with-c-callables around their body.
;;
;; C++ gives a range (a TypeRange, say) as a pointer to an array and a count, not as a Scheme
;; list; crest-callback-pointer-list reads the count elements of 8 bytes at pointer.
;;
;;===----------------------------------------------------------------------===;;
(library (crest callback)
  (export crest-make-static-c-callable
          with-c-callable
          with-c-callables
          crest-call-guarded
          crest-guard-procedure
          crest-callback-pointer-list
          crest-callback-entry-dispatcher)
  (import (chezscheme)
          (for (mlir support srcloc) expand)
          (mlir support foreign)
          (mlir support RAII)
          (only (mlir IR MLIRContext) current-MLIRContext)
          (only (mlir IR Location ffi) %mlir::UnknownLoc::get)
          (only (mlir IR Diagnostics ffi) %mlir::emitError)
          (only (llvm Support ErrorHandling ffi) %llvm::report_fatal_error))

  ;; ---- no error leaves a callable ------------------------------------------------------------------
  ;;
  ;; C++ calls a callable through a C function pointer. An error that escaped it would cross the C++
  ;; frames (skipping their destructors, and leaving a record in Chez for each), so every callable
  ;; catches the error itself and reports it, as the header says. Only crest-call-guarded, which C++ calls
  ;; by name for the pass of --crest-pass, still answers an error as a value: the pair (who . why), who a
  ;; symbol and why a string (lib/Bindings/Support/Result.h: isSchemeError, emitSchemeError).

  ;; The who of the condition, as a string ("" when it has none).
  (define (%%condition-who c)
    (if (and (condition? c) (who-condition? c) (condition-who c))
        (let ([who (condition-who c)])
          (cond [(string? who) who]
                [(symbol? who) (symbol->string who)]
                [else (call-with-string-output-port (lambda (port) (write who port)))]))
        ""))

  ;; The text of the condition: the message and the irritants, as `error` was given them.
  (define (%%condition-message c)
    (call-with-string-output-port
     (lambda (port)
       (cond
        [(and (condition? c) (message-condition? c))
         (display (condition-message c) port)
         (when (irritants-condition? c)
           (for-each (lambda (irritant) (display " " port) (write irritant port))
                     (condition-irritants c)))]
        [(condition? c) (display-condition c port)]
        [else (write c port)]))))

  ;; The procedure, with its error answered as (who . why).
  (define (%%guard procedure)
    (lambda arguments
      (guard (c [#t (cons (string->symbol (%%condition-who c)) (%%condition-message c))])
        (apply procedure arguments))))

  ;; ---- the guard of a callable (plan 05) ----------------------------------------------------------
  ;;
  ;; MLIR declares the prototype, and it has no room for an error, so when the procedure raises the guard
  ;; reports "<file>:<line>:<column>: <who>: <why>" (the Scheme position of the callback, then the error):
  ;;   result void       nothing can say "failed": the process ends with the text (llvm::report_fatal_error)
  ;;   any other result  mlir::emitError with the text, in (current-MLIRContext), and the zero of the C
  ;;                     result type is answered so that the function can return; with no current context
  ;;                     nothing can be emitted, and the process ends with the text
  ;; LOCATION is (file line column), read when the macro expands, or #f.

  ;; "who: message", or the message when the condition has no who.
  (define (%%error-text c)
    (let ([who (%%condition-who c)]
          [message (%%condition-message c)])
      (if (string=? who "") message (string-append who ": " message))))

  ;; "<file>:<line>:<column>: <who>: <why>"
  (define (%%diagnostic-text c location)
    (if location
        (format "~a:~a:~a: ~a" (car location) (cadr location) (caddr location) (%%error-text c))
        (%%error-text c)))

  (define (%%report c location)
    (let ([context (current-MLIRContext)]
          [text (%%diagnostic-text c location)])
      (if context
          (guard (reporting-error [#t (%llvm::report_fatal_error text)])
            (%mlir::emitError (%mlir::UnknownLoc::get context) text))
          (%llvm::report_fatal_error text))))

  ;; The procedure, with its error reported and ZERO answered (the zero of the C result type).
  (define (%%report-guard procedure location zero)
    (lambda arguments
      (guard (c [#t (%%report c location) zero])
        (apply procedure arguments))))

  ;; The procedure, with its error ending the process (the C result is void).
  (define (%%fatal-guard procedure location)
    (lambda arguments
      (guard (c [#t (%llvm::report_fatal_error (%%diagnostic-text c location))])
        (apply procedure arguments))))

  ;; (crest-guard-procedure procedure location zero): the procedure with its error reported, as the guard
  ;; of a callable does it, and ZERO answered. For a Scheme procedure that C++ calls itself while a
  ;; callable runs (the clauses of InferTypeOpInterface): an error must not cross the C++ frames either.
  (define (crest-guard-procedure procedure location zero)
    (%%report-guard procedure location zero))

  ;; The guard of a callable by the kind of its result: void has no place for an error, a range answers
  ;; (data . size), the others are numbers.
  (define (%%guard-for-result result procedure location)
    (case result
      [(void) (%%fatal-guard procedure location)]
      [(range) (%%report-guard procedure location (cons 0 0))]
      [else (%%report-guard procedure location 0)]))

  ;; A pair of words that C++ passes or returns by value: an llvm::ArrayRef, a TypeRange, an
  ;; OperandRange (a pointer and a count). Chez makes a foreign-callable that takes or answers such a
  ;; struct follow the rules of the platform: two registers on Linux, a pointer to a copy on Windows.
  (define-ftype %%SlotRange (struct [data uptr] [size uptr]))

  ;; The elements of a range C++ gave as two words (crest::TypeRange::toList): a TypeRange is not an
  ;; array, its first word has a tag.
  (define %%type-range->list
    (crest-foreign-procedure "crest::TypeRange::toList" (uptr uptr) scheme-object))

  ;; Windows x64 (a6nt, ta6nt): a class with a constructor is returned through a pointer even when
  ;; it is one word (Type, StringAttr, a PointerUnion, LogicalResult, WalkResult), where it is passed in a
  ;; register.
  (define (%%windows?)
    (let* ([name (symbol->string (machine-type))]
           [n (string-length name)])
      (and (>= n 2) (string=? (substring name (- n 2) n) "nt"))))

  ;; (%%make-code (kind ...) result-kind procedure location): the code object of the foreign-callable whose
  ;; C prototype is the one of C++. LOCATION is an expression for the position of the callback, (file line
  ;; column) or #f. The kinds are the C++ types:
  ;;   arguments  uptr, int, ... (any type of foreign-callable), and
  ;;     type-range     a TypeRange by value (16 bytes): the procedure gets the list of the types
  ;;   results    void, uptr, int, unsigned-8 (a bool), and the types that C++ answers by value:
  ;;     object         a class of one pointer (Type, TypeAttr, StringAttr, ...): the procedure answers the pointer
  ;;     logical-result an llvm::LogicalResult (one byte, 1 for success)
  ;;     walk-result    an mlir::WalkResult (4 bytes, constants in (mlir Support WalkResult))
  ;;     range          an ArrayRef or an OperandRange: the procedure answers (data . size)
  ;; Windows x64 answers a class with a constructor (object, logical-result, walk-result) through the place that
  ;; the caller gives, a pointer before the other arguments: the function writes its answer there, and answers
  ;; the pointer. SlotAbiTest (unittests/Crest/InterfaceTest.cpp) calls a callable of each kind through a
  ;; function pointer of the exact type, on Linux and Windows.
  (define-syntax %%make-code
    (lambda (stx)
      (syntax-case stx ()
        [(_ (kind ...) result procedure location)
         (let* ([kinds (syntax->list #'(kind ...))]
                [formals (generate-temporaries kinds)]
                [types (map (lambda (k)
                              (if (eq? (syntax->datum k) 'type-range) #'(& %%SlotRange) k))
                            kinds)]
                [values (map (lambda (k formal)
                               (if (eq? (syntax->datum k) 'type-range)
                                   #`(%%type-range->list (ftype-ref %%SlotRange (data) #,formal)
                                                         (ftype-ref %%SlotRange (size) #,formal))
                                   formal))
                             kinds formals)]
                ;; a class answered by value: the size of its answer, and its C type where it is a register
                [class-answer
                 (lambda (size linux-type)
                   #`(if (%%windows?)
                         (foreign-callable
                          (lambda (answer #,@formals)
                            (foreign-set! '#,size answer 0 (p #,@values))
                            answer)
                          (uptr #,@types) uptr)
                         (foreign-callable (lambda (#,@formals) (p #,@values))
                                           (#,@types) #,linux-type)))])
           #`(let ([p (%%guard-for-result 'result procedure location)])
               #,(case (syntax->datum #'result)
                   [(void uptr int unsigned-8)
                    #`(foreign-callable (lambda (#,@formals) (p #,@values)) (#,@types) result)]
                   [(object) (class-answer #'uptr #'uptr)]
                   [(logical-result) (class-answer #'unsigned-8 #'unsigned-8)]
                   [(walk-result) (class-answer #'unsigned-32 #'int)]
                   [(range)
                    #`(foreign-callable
                       (lambda (answer #,@formals)
                         (let ([pair (p #,@values)])
                           (ftype-set! %%SlotRange (data) answer (car pair))
                           (ftype-set! %%SlotRange (size) answer (cdr pair))))
                       (#,@types) (& %%SlotRange))]
                   [else
                    (syntax-violation 'crest-make-static-c-callable
                                      "unknown result kind of a callable" stx #'result)])))])))

  ;; (crest-call-guarded procedure argument ...): C++ calls a Scheme procedure itself (the pass of
  ;; --crest-pass): the answer of the procedure, or the pair (who . why) when it raised an error.
  (define (crest-call-guarded procedure . arguments)
    (apply (%%guard procedure) arguments))

  ;; (crest-make-static-c-callable (argument-type ...) result-type procedure [:source expression | :location expression]): the
  ;; address of a C function with the prototype of C++: those argument types and that result type. It locks
  ;; the callable for good: use it only at the library level, for a callback that uses no state of a run.
  ;; The argument and result kinds are those of %%make-code (above): the C++ types, class types by value
  ;; included. An error of the procedure is reported by its guard (see above), at the Scheme position of PROCEDURE, or of the expression after :source when a macro wraps the procedure of
  ;; its user in a lambda of its own and the position of the user is the useful one. :location gives the
  ;; position as an expression that is evaluated when the callable is made, (file line column) or #f: for a
  ;; procedure that reaches the macro as a value and whose position was read where it was written.
  (define-syntax crest-make-static-c-callable
    (lambda (stx)
      (define (location-of options default)
        (syntax-case options ()
          [() (position-of default)]
          [(key source) (eq? (syntax->datum #'key) ':source) (position-of #'source)]
          [(key expression) (eq? (syntax->datum #'key) ':location) #'expression]
          [_ (syntax-violation 'crest-make-static-c-callable "expected :source or :location" stx
                               options)]))
      (define (position-of form)
        (with-syntax ([position (datum->syntax
                                 #'stx
                                 (or (syntax->first-file+line+col form)
                                     (syntax->file+line+col stx)))])
          #''position))
      (syntax-case stx ()
        [(_ (type ...) result proc . options)
         (with-syntax ([location (location-of #'options #'proc)])
           #'(let ([code (%%make-code (type ...) result proc location)])
               (lock-object code)
               (foreign-callable-entry-point code)))])))

  ;; (with-c-callable (name (argument-type ...) result-type value [:source expression]) body ...)
  ;;
  ;; Runs BODY with NAME bound to the address of a C function with the prototype of C++ (those argument types
  ;; and that result type, as for crest-make-static-c-callable) that calls what VALUE is:
  ;;
  ;;   a procedure: the macro makes the foreign-callable, locks it, and unlocks it when BODY ends, also
  ;;   when it ends by an error. Use it for a callback that C++ calls while BODY runs.
  ;;
  ;;   a callable that the caller made and keeps locked, to reuse it (making one costs about 200 ns):
  ;;   the code object of foreign-callable after lock-object, or an address that
  ;;   crest-make-static-c-callable answered. The macro uses it as it is and never unlocks it, because
  ;;   it is the caller's. An unlocked code object is an error: the garbage collector could move it,
  ;;   and C++ would call a stale address. The types are not used for these.
  ;;
  ;; The address is only valid inside BODY: if C++ keeps it after BODY ends, use
  ;; crest-make-static-c-callable. The diagnostic of an error is at the Scheme position of VALUE, or of the
  ;; expression after :source (see crest-make-static-c-callable).
  (define-syntax with-c-callable
    (lambda (stx)
      (define (location-of options default)
        (syntax-case options ()
          [() (position-of default)]
          [(key source) (eq? (syntax->datum #'key) ':source) (position-of #'source)]
          [_ (syntax-violation 'with-c-callable "expected :source expression" stx options)]))
      (define (position-of form)
        (with-syntax ([position (datum->syntax
                                 #'stx
                                 (or (syntax->first-file+line+col form)
                                     (syntax->file+line+col stx)))])
          #''position))
      (syntax-case stx ()
        [(_ (name (type ...) result value . options) body ...)
         (with-syntax ([location (location-of #'options #'value)])
           #'(let* ([given value]
                    [made? (procedure? given)]
                    [code (cond
                           [made? (%%make-code (type ...) result given location)]
                           [(and (integer? given) (exact? given)) (foreign-callable-code-object given)]
                           [else given])])
               (when made? (lock-object code))
               (unless (locked-object? code)
                 (assertion-violation 'with-c-callable
                                      "the callable must be a procedure, or a locked code object, or the address of a locked callable"
                                      given))
               (with-raii locked (and made? code)
                          (lambda (locked) (when locked (unlock-object locked)))
                 (let ([name (foreign-callable-entry-point code)]) body ...))))])))

  ;; (with-c-callables ((name (type ...) value) ...) body ...): with-c-callable for each binding,
  ;; the first made first and released last. A binding may use the names of the ones before it.
  (define-syntax with-c-callables
    (syntax-rules ()
      [(_ () body ...) (let () body ...)]
      [(_ (binding rest ...) body ...)
       (with-c-callable binding (with-c-callables (rest ...) body ...))]))

  (define (crest-callback-pointer-list pointer count)
    (map (lambda (i) (foreign-ref 'uptr pointer (* i 8))) (iota count)))

  ;; What the macro of an interface hands to C++ (the :interfaces clause of define-op): from a method
  ;; name to the entry point of its callable, 0 for a method that the op has no clause for. C++ asks
  ;; for each method of the interface while it registers the op (lib/Crest/Interface.h). `entries`
  ;; is an alist of (method . entry point).
  (define (crest-callback-entry-dispatcher entries)
    (lambda (method)
      (cond
       [(assq method entries) => cdr]
       [else 0])))

  ) ;; end library (crest callback)

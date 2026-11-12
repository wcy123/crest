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
;;   (crest-make-static-c-callable (argument-type ...) proc)   an address
;;   (crest-callback-pointer-list pointer count)              a list of integers
;;   (crest-callback-entry-dispatcher entries)                a procedure
;;
;; C++ never makes, owns, locks or releases a callback. A binding that needs one takes a plain C
;; function pointer; Scheme makes the foreign-callable (locked, because the garbage collector moves
;; code objects) and whoever calls the low-level function decides how long it lives. The argument
;; types are those of foreign-callable (uptr, int, ...). The C function answers a Scheme object: what
;; the procedure answered (a number, #t, #f, void), or the pair (who . why) when it raised an error:
;; the procedure never raises into C++, and C++ reads the answer (lib/Bindings/Support/Result.h).
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
          crest-make-raw-c-callable
          crest-callback-pointer-list
          crest-callback-entry-dispatcher
          crest-slot-callable)
  (import (chezscheme)
          (for (mlir support srcloc) expand)
          (mlir support foreign)
          (mlir support RAII)
          (only (mlir IR MLIRContext) current-MLIRContext)
          (only (mlir IR Location ffi) %mlir::FileLineColLoc::get %mlir::UnknownLoc::get)
          (only (mlir IR Diagnostics ffi) %mlir::emitError)
          (only (llvm Support ErrorHandling ffi) %llvm::report_fatal_error))

  ;; ---- no error leaves a callable ------------------------------------------------------------------
  ;;
  ;; C++ calls a callable through a C function pointer. An error that escaped it would cross the C++
  ;; frames (skipping their destructors, and leaving a record in Chez for each), so every callable
  ;; catches the error itself and answers it as a value: the pair (who . why), who a symbol and why a
  ;; string. Its answer is a Scheme object (a number, #t, #f, void, or that pair), and the C++ code that
  ;; made the call reads it (lib/Bindings/Support/Result.h: isSchemeError, emitSchemeError) and reports
  ;; the error as a diagnostic.
  ;;
  ;; The callables of an interface slot are the exception: MLIR calls them with its own prototype, so
  ;; they cannot answer a pair, and their procedures must not raise.

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

  ;; ---- the guard of a callable whose C result is not a Scheme object (plan 05) ------------------------
  ;;
  ;; MLIR declares the prototype, and it has no room for an error. The guard reports the error through
  ;; MLIR's own channel and answers what the prototype can hold:
  ;;   result void       nothing can say "failed": the process ends with the text (llvm::report_fatal_error)
  ;;   any other result  a diagnostic at the Scheme source of the callback, then the failure value of the type
  ;;                     (0, #f, interrupt for a WalkResult)
  ;; LOCATION is (file line column) of the callback in the Scheme source, read when the macro expands, or #f.
  ;; A location belongs to a context: it is made in (current-MLIRContext). With no current context the process
  ;; ends with the text and the position.

  ;; "who: message", or the message when the condition has no who.
  (define (%%error-text c)
    (let ([who (%%condition-who c)]
          [message (%%condition-message c)])
      (if (string=? who "") message (string-append who ": " message))))

  (define (%%position-text location)
    (if location
        (format "~a:~a:~a" (car location) (cadr location) (caddr location))
        "unknown position"))

  ;; Ends the process: nothing after the call runs.
  (define (%%die c location)
    (%llvm::report_fatal_error
     (string-append (%%error-text c) " (" (%%position-text location) ")")))

  (define (%%report c location)
    (let ([context (current-MLIRContext)])
      (if context
          (guard (reporting-error [#t (%%die c location)])
            (%mlir::emitError
             (if location
                 (%mlir::FileLineColLoc::get context (car location) (cadr location) (caddr location))
                 (%mlir::UnknownLoc::get context))
             (%%error-text c)))
          (%%die c location))))

  ;; The procedure, with its error reported and ZERO answered (the failure value of the C result type).
  (define (%%report-guard procedure location zero)
    (lambda arguments
      (guard (c [#t (%%report c location) zero])
        (apply procedure arguments))))

  ;; The procedure, with its error ending the process (the C result is void).
  (define (%%fatal-guard procedure location)
    (lambda arguments
      (guard (c [#t (%%die c location)])
        (apply procedure arguments))))

  ;; Windows x64 answers a WalkResult (a class with constructors) through the place that the caller
  ;; gives, a pointer before the arguments, as it does for a LogicalResult (crest-slot-callable).
  (define (%%windows-result procedure)
    (lambda (answer . arguments)
      (foreign-set! 'unsigned-32 answer 0 (apply procedure arguments))
      answer))

  ;; (%%make-code (argument-type ...) result-type procedure location): LOCATION is an expression for the
  ;; position of the callback, (file line column) or #f. The code object of the foreign-callable
  ;; for that result type. scheme-object keeps the answer as (who . why) while the hooks move to their natural
  ;; type; walk-result is the C++ class mlir::WalkResult (4 bytes, constants in (mlir Support WalkResult)).
  (define-syntax %%make-code
    (lambda (stx)
      (syntax-case stx ()
        [(_ (type ...) result procedure location)
         (case (syntax->datum #'result)
           [(scheme-object)
            #'(foreign-callable (%%guard procedure) (type ...) scheme-object)]
           [(void)
            #'(foreign-callable (%%fatal-guard procedure location) (type ...) void)]
           [(boolean)
            #'(foreign-callable (%%report-guard procedure location #f) (type ...) boolean)]
           [(int uptr unsigned-8 unsigned-32)
            #'(foreign-callable (%%report-guard procedure location 0) (type ...) result)]
           [(walk-result)
            #'(if (%%windows?)
                  (foreign-callable (%%windows-result (%%report-guard procedure location 0))
                                    (uptr type ...) uptr)
                  (foreign-callable (%%report-guard procedure location 0) (type ...) int))]
           [else
            (syntax-violation 'crest-make-static-c-callable "unknown result type of a callable" stx
                              #'result)])])))

  ;; (crest-call-guarded procedure argument ...): C++ calls a Scheme procedure itself (the pass of
  ;; --crest-pass): the answer of the procedure, or the pair (who . why) when it raised an error.
  (define (crest-call-guarded procedure . arguments)
    (apply (%%guard procedure) arguments))

  ;; A pair of words that C++ passes or returns by value: an llvm::ArrayRef, a TypeRange, an
  ;; OperandRange (a pointer and a count). Chez makes a foreign-callable that takes or answers such a
  ;; struct follow the rules of the platform: two registers on Linux, a pointer to a copy on Windows.
  (define-ftype %%SlotRange (struct [data uptr] [size uptr]))

  ;; The elements of a range C++ gave as two words (crest::TypeRange::toList): a TypeRange is not an
  ;; array, its first word has a tag.
  (define %%type-range->list
    (crest-foreign-procedure "crest::TypeRange::toList" (uptr uptr) scheme-object))

  ;; Windows x64 (a6nt, ta6nt): a class with a constructor is returned through a pointer even when
  ;; it is one word (Type, StringAttr, a PointerUnion), where it is passed in a register.
  (define (%%windows?)
    (let* ([name (symbol->string (machine-type))]
           [n (string-length name)])
      (and (>= n 2) (string=? (substring name (- n 2) n) "nt"))))

  ;; (crest-make-static-c-callable (argument-type ...) result-type procedure [:source expression | :location expression]): the
  ;; address of a C function with the prototype of C++: those argument types and that result type. It locks
  ;; the callable for good: use it only at the library level, for a callback that uses no state of a run.
  ;; result-type: scheme-object (the answer, or (who . why) for an error), void, int, uptr, unsigned-8,
  ;; unsigned-32, boolean, walk-result. An error of the procedure is reported by its guard (see above), at
  ;; the Scheme position of PROCEDURE, or of the expression after :source when a macro wraps the procedure of
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

  ;; (crest-make-raw-c-callable (argument-type ...) result-type procedure): the same for a slot of a
  ;; Concept, which MLIR calls with its own prototype: the procedure is not guarded (it must not raise),
  ;; and the C function has the C result type of the slot.
  (define-syntax crest-make-raw-c-callable
    (syntax-rules ()
      [(_ (argument-type ...) result-type proc)
       (let ([code (foreign-callable proc (argument-type ...) result-type)])
         (lock-object code)
         (foreign-callable-entry-point code))]))

  ;; (with-c-callable (name (argument-type ...) result-type value [:source expression | :location expression]) body ...)
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
          [(key expression) (eq? (syntax->datum #'key) ':location) #'expression]
          [_ (syntax-violation 'with-c-callable "expected :source or :location" stx options)]))
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

  ;; The callable of a slot of a Concept, which MLIR calls as a C function: a pointer to the Concept
  ;; first (ignored), then the arguments of the method. The kinds are the C++ types of the slot, and
  ;; the macro writes the prototype of the platform, so the procedure sees numbers and lists:
  ;;
  ;;   (crest-slot-callable (argument-kind ...) result-kind procedure)
  ;;
  ;; argument kinds: uptr, int, unsigned-8 (a bool), unsigned-32, and
  ;;   object       a class of one pointer (Type, TypeAttr, StringAttr, ...), by value: the procedure gets
  ;;                the pointer, on every platform (an argument of one word is passed in a register)
  ;;   type-range   a TypeRange by value: the procedure gets the list of the types
  ;; result kinds: void, uptr, int, unsigned-8, unsigned-32, and
  ;;   object       the procedure answers the pointer; Windows x64 answers a class that has a
  ;;                constructor through the place that the caller gives (a pointer before the Concept)
  ;;   logical-result  an llvm::LogicalResult (one byte, 1 for success): Windows x64 answers it
  ;;                through the place that the caller gives, as for an object
  ;;   range        an ArrayRef or an OperandRange: the procedure answers (data . size)
  ;; The procedure gets only the arguments, not the Concept. Answers the entry point, as
  ;; crest-make-static-c-callable does.
  (define-syntax crest-slot-callable
    (lambda (stx)
      (define (argument-info kind windows?)
        ;; a pair: the C type, and a procedure from the formal to the expression
        (case (syntax->datum kind)
          [(uptr int unsigned-8 unsigned-32) (cons kind (lambda (formal) formal))]
          [(object) (cons #'uptr (lambda (formal) formal))]
          [(type-range)
           (cons #'(& %%SlotRange)
                 (lambda (formal)
                   #`(%%type-range->list (ftype-ref %%SlotRange (data) #,formal)
                                         (ftype-ref %%SlotRange (size) #,formal))))]
          [else (syntax-violation 'crest-slot-callable "unknown kind of argument" stx kind)]))
      (define (callable windows? kinds result procedure)
        (let* ([formals (generate-temporaries kinds)]
               [infos (map (lambda (kind) (argument-info kind windows?)) kinds)]
               [types (map car infos)]
               [values (map (lambda (info formal) ((cdr info) formal)) infos formals)])
          (case (syntax->datum result)
            [(void uptr int unsigned-8 unsigned-32)
             #`(crest-make-raw-c-callable
                (uptr #,@types) #,result
                (lambda (concept #,@formals) (#,procedure #,@values)))]
            [(object)
             (if windows?
                 #`(crest-make-raw-c-callable
                    (uptr uptr #,@types) uptr
                    (lambda (answer concept #,@formals)
                      (foreign-set! 'uptr answer 0 (#,procedure #,@values))
                      answer))
                 #`(crest-make-raw-c-callable
                    (uptr #,@types) uptr
                    (lambda (concept #,@formals) (#,procedure #,@values))))]
            [(logical-result)
             (if windows?
                 #`(crest-make-raw-c-callable
                    (uptr uptr #,@types) uptr
                    (lambda (answer concept #,@formals)
                      (foreign-set! 'unsigned-8 answer 0 (#,procedure #,@values))
                      answer))
                 #`(crest-make-raw-c-callable
                    (uptr #,@types) unsigned-8
                    (lambda (concept #,@formals) (#,procedure #,@values))))]
            [(range)
             #`(crest-make-raw-c-callable
                (uptr #,@types) (& %%SlotRange)
                (lambda (answer concept #,@formals)
                  (let ([pair (#,procedure #,@values)])
                    (ftype-set! %%SlotRange (data) answer (car pair))
                    (ftype-set! %%SlotRange (size) answer (cdr pair)))))]
            [else (syntax-violation 'crest-slot-callable "unknown kind of result" stx result)])))
      (syntax-case stx ()
        [(_ (kind ...) result procedure)
         #`(let ([p procedure])
             (if (%%windows?)
                 #,(callable #t #'(kind ...) #'result #'p)
                 #,(callable #f #'(kind ...) #'result #'p)))])))

  ) ;; end library (crest callback)

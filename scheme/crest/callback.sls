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
;;                                  value is a procedure, or the address of a locked callable that the
;;                                  caller made (reused, never unlocked here).
;;
;; Several of them nest with with* ((mlir support with)). The conversion clauses (with-TypeConverter,
;; with-ConversionTarget, with-RewritePatternSet) do that around their body.
;;
;; C++ gives a range (a TypeRange, say) as a pointer to an array and a count, not as a Scheme
;; list; crest-callback-pointer-list reads the count elements of 8 bytes at pointer.
;;
;;===----------------------------------------------------------------------===;;
(library (crest callback)
  (export crest-make-static-c-callable
          with-c-callable
          crest-call-guarded
          crest-callback-pointer-list)
  (import (chezscheme)
          (for (mlir support srcloc) expand)
          (mlir support foreign)
          (mlir support RAII)
          (only (mlir IR MLIRContext) current-MLIRContext)
          (only (mlir IR Location ffi) %mlir::UnknownLoc::get)
          (only (mlir IR Diagnostics ffi) %mlir::emitError)
          (only (llvm Support ErrorHandling ffi) %llvm::report_fatal_error))

  ;; ---- what a callback is made with --------------------------------------------------------------------

  ;; @brief crest-make-static-c-callable — make a C function with the prototype of C++ from a procedure,
  ;;        locked for good.
  ;; @param argument-type  the C++ argument kinds, in order: uptr, int, ... (any type of foreign-callable)
  ;;                       or type-range (see %%make-code)
  ;; @param result-type    the C++ result kind: void, uptr, int, unsigned-8, object, logical-result,
  ;;                       walk-result or range (see %%make-code)
  ;; @param procedure      the procedure that the C function calls, with the arguments as Scheme values
  ;; @param :source        optional: an expression whose Scheme position names the callback in an error
  ;;                       report. For a macro that wraps the procedure of its user in a lambda of its own,
  ;;                       when the position of the user is the useful one
  ;; @param :location      optional: an expression, evaluated when the callable is made, for the position
  ;;                       as data, (file line column) or #f. For a procedure that reaches the macro as a
  ;;                       value, whose position was read where it was written
  ;; @return               the address of the C function, an exact integer
  ;; @note                 A macro. It locks the callable for good: use it only at the library level, for a
  ;;                       callback that uses no state of a run. An error of the procedure is reported by
  ;;                       the guard (see %%guard-for-result), at the Scheme position of PROCEDURE or of
  ;;                       :source.
  ;; @example
  ;;   (define legal (crest-make-static-c-callable (uptr) int (lambda (op) 1)))
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

  ;; @brief with-c-callable — run a body with the address of a C function made from a procedure.
  ;; @param name           identifier bound to the address inside BODY
  ;; @param argument-type  as for crest-make-static-c-callable; not used when VALUE is an address
  ;; @param result-type    as for crest-make-static-c-callable; not used when VALUE is an address
  ;; @param value          a procedure, or an address. A procedure: the macro makes the foreign-callable,
  ;;                       locks it, and unlocks it when BODY ends, also when it ends by an error; use it for
  ;;                       a callback that C++ calls while BODY runs. An address that
  ;;                       crest-make-static-c-callable answered, to reuse it (making one costs about 200
  ;;                       ns): used as it is and never unlocked, because it is the caller's; a callable that
  ;;                       is not locked is an error, because the garbage collector could move it and C++
  ;;                       would call a stale address
  ;; @param :source        optional, as for crest-make-static-c-callable
  ;; @param body           expressions evaluated with NAME bound
  ;; @return               the value of the last expression of BODY
  ;; @note                 A macro. The address is valid only inside BODY: if C++ keeps it after BODY ends,
  ;;                       use crest-make-static-c-callable. An error of the procedure is reported at the
  ;;                       Scheme position of VALUE or of :source.
  ;; @example
  ;;   (with-c-callable (visit (uptr) walk-result (lambda (op) mlir::WalkResult::advance))
  ;;     (call-cpp visit))
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
                           [else (assertion-violation 'with-c-callable
                                                      "the value must be a procedure or the address of a locked callable"
                                                      given)])])
               (when made? (lock-object code))
               (unless (locked-object? code)
                 (assertion-violation 'with-c-callable
                                      "the callable of this address is not locked"
                                      given))
               (with-raii locked (and made? code)
                          (lambda (locked) (when locked (unlock-object locked)))
                 (let ([name (foreign-callable-entry-point code)]) body ...))))])))

  ;; @brief crest-call-guarded — call a Scheme procedure for C++ under the guard of a callable.
  ;; @param procedure  the procedure to call
  ;; @param argument   its arguments
  ;; @return           1 when the procedure returned, 0 after its error was reported
  ;; @note             C++ calls it by name for the pass of --crest-pass, which has no C prototype to
  ;;                   match. The error is reported without a Scheme position.
  (define (crest-call-guarded procedure . arguments)
    (apply (%%report-guard (lambda arguments (apply procedure arguments) 1) #f 0) arguments))

  ;; @brief crest-callback-pointer-list — read a range that C++ gave as a pointer and a count.
  ;; @param pointer  the address of an array of 8-byte elements (a pointer or an integer each)
  ;; @param count    the number of elements
  ;; @return         the elements, a list of integers
  (define (crest-callback-pointer-list pointer count)
    (map (lambda (i) (foreign-ref 'uptr pointer (* i 8))) (iota count)))

  ;; ---- the C function of one callable: its prototype is the one of C++ ---------------------------------

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

  ;; ---- the guard of a callable (plan 05) ----------------------------------------------------------
  ;;
  ;; MLIR declares the prototype, and it has no room for an error, so when the procedure raises the guard
  ;; reports "<file>:<line>:<column>: <who>: <why>" (the Scheme position of the callback, then the error):
  ;;   result void       nothing can say "failed": the process ends with the text (llvm::report_fatal_error)
  ;;   any other result  mlir::emitError with the text, in (current-MLIRContext), and the zero of the C
  ;;                     result type is answered so that the function can return; with no current context
  ;;                     nothing can be emitted, and the process ends with the text
  ;; LOCATION is (file line column), read when the macro expands, or #f.

  ;; The guard of a callable by the kind of its result: void has no place for an error, a range answers
  ;; (data . size), the others are numbers.
  (define (%%guard-for-result result procedure location)
    (case result
      [(void) (%%fatal-guard procedure location)]
      [(range) (%%report-guard procedure location (cons 0 0))]
      [else (%%report-guard procedure location 0)]))

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

  (define (%%report c location)
    (let ([context (current-MLIRContext)]
          [text (%%diagnostic-text c location)])
      (if context
          (guard (reporting-error [#t (%llvm::report_fatal_error text)])
            (%mlir::emitError (%mlir::UnknownLoc::get context) text))
          (%llvm::report_fatal_error text))))

  ;; "<file>:<line>:<column>: <who>: <why>"
  (define (%%diagnostic-text c location)
    (if location
        (format "~a:~a:~a: ~a" (car location) (cadr location) (caddr location) (%%error-text c))
        (%%error-text c)))

  ;; "who: message", or the message when the condition has no who.
  (define (%%error-text c)
    (let ([who (%%condition-who c)]
          [message (%%condition-message c)])
      (if (string=? who "") message (string-append who ": " message))))

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

  ;; The who of the condition, as a string ("" when it has none).
  (define (%%condition-who c)
    (if (and (condition? c) (who-condition? c) (condition-who c))
        (let ([who (condition-who c)])
          (cond [(string? who) who]
                [(symbol? who) (symbol->string who)]
                [else (call-with-string-output-port (lambda (port) (write who port)))]))
        ""))

  ;; ---- the C++ classes that are passed or answered by value --------------------------------------------

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

  ) ;; end library (crest callback)

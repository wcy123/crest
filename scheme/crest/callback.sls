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
;; every site (uptr, int, unsigned-8, void, walk-result, ...; the types are listed at %%make-code), and a mismatch crashes, as C++ does not check it.
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
;;   define-c-callable              the same, as a definition: (define-c-callable name (type ...) result-type
;;                                  procedure).
;;   with-c-callable/lambda         makes it from a procedure, locks it for the body and unlocks it after,
;;                                  also on an error.
;;   with-c-callable/code           uses the address of a locked callable that the caller made (reused,
;;                                  never unlocked here).
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
          define-c-callable
          with-c-callable/lambda
          with-c-callable/code
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
  ;; @param argument-type  the C++ argument types, in order: uptr, int, ... (any type of foreign-callable)
  ;;                       or type-range (see %%make-code)
  ;; @param result-type    the C++ result type: void, uptr, int, unsigned-8, object, logical-result,
  ;;                       walk-result or range (see %%make-code)
  ;; @param procedure      the procedure that the C function calls, with the arguments as Scheme values
  ;; @return               the address of the C function, an exact integer
  ;; @note                 A macro. It locks the callable for good: use it only at the library level, for a
  ;;                       callback that uses no state of a run. An error of the procedure is reported by
  ;;                       the guard (see %%guard-for-result), at the Scheme position of PROCEDURE: the
  ;;                       part of the form that is the user's, when a macro built the form.
  ;; @example
  ;;   (define legal (crest-make-static-c-callable (uptr) int (lambda (op) 1)))
  (define-syntax crest-make-static-c-callable
    (lambda (stx)
      (syntax-case stx ()
        [(_ (type ...) result-type procedure)
         (with-syntax ([location #`(quote #,(datum->syntax #'stx (syntax->first-file+line+col #'procedure)))])
           #'(let ([code (%%make-code (type ...) result-type procedure location)])
               (lock-object code)
               (foreign-callable-entry-point code)))])))

  ;; @brief define-c-callable — define NAME as the address of a C function made once, for the whole program.
  ;; @param name           identifier defined as the address
  ;; @param argument-type  as for crest-make-static-c-callable
  ;; @param result-type    as for crest-make-static-c-callable
  ;; @param procedure      the procedure that the C function calls
  ;; @note                 A macro, like define: it links a C function into the library for good, as a
  ;;                       static library does. Use it at the library level, for a callback that uses no
  ;;                       state of a run, that C++ keeps after the call that registers it returns (the
  ;;                       address that add-rewrite-pattern and add-conversion-pattern take).
  ;; @example
  ;;   (define-c-callable cast-callable (uptr uptr uptr uptr) int (conversion-pattern->c onnx-cast->hipsr))
  (define-syntax define-c-callable
    (syntax-rules ()
      [(_ name (type ...) result-type procedure)
       (define name (crest-make-static-c-callable (type ...) result-type procedure))]))

  ;; @brief with-c-callable/lambda — run a body with the address of a C function made from a procedure.
  ;; @param name           identifier bound to the address inside BODY
  ;; @param argument-type  as for crest-make-static-c-callable
  ;; @param result-type    as for crest-make-static-c-callable
  ;; @param procedure      the procedure that the C function calls. The macro makes the foreign-callable,
  ;;                       locks it, and unlocks it when BODY ends, also when it ends by an error
  ;; @param body           expressions evaluated with NAME bound
  ;; @return               the value of the last expression of BODY
  ;; @note                 A macro. Use it for a callback that C++ calls while BODY runs. The address is
  ;;                       valid only inside BODY: if C++ keeps it after BODY ends, use
  ;;                       crest-make-static-c-callable. An error of the procedure is reported at the Scheme
  ;;                       position of PROCEDURE.
  ;; @example
  ;;   (with-c-callable/lambda (visit (uptr) walk-result (lambda (op) mlir::WalkResult::advance))
  ;;     (call-cpp visit))
  (define-syntax with-c-callable/lambda
    (lambda (stx)
      (syntax-case stx ()
        [(_ (name (type ...) result-type procedure) body ...)
         (with-syntax ([location #`(quote #,(datum->syntax #'stx (syntax->first-file+line+col #'procedure)))])
           #'(let ([code (%%make-code (type ...) result-type procedure location)])
               (lock-object code)
               (with-raii locked code
                          (lambda (locked) (unlock-object locked))
                 (let ([name (foreign-callable-entry-point code)]) body ...))))])))

  ;; @brief with-c-callable/code — run a body with the address of a callable that someone else made.
  ;; @param name     identifier bound to the address inside BODY
  ;; @param address  the address that crest-make-static-c-callable answered, to reuse it (making a callable
  ;;                 costs about 200 ns). The macro never unlocks it, because it is the caller's. A callable
  ;;                 that is not locked is an error: the garbage collector could move it, and C++ would
  ;;                 call a stale address
  ;; @param body     expressions evaluated with NAME bound
  ;; @return         the value of the last expression of BODY
  (define-syntax with-c-callable/code
    (syntax-rules ()
      [(_ (name address) body ...)
       (let ([name address])
         (unless (and (integer? name) (exact? name)
                      (locked-object? (foreign-callable-code-object name)))
           (assertion-violation 'with-c-callable/code "the address must be that of a locked callable" name))
         body ...)]))

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

  ;; (%%make-code (type ...) result-type procedure location): the code object of the foreign-callable whose
  ;; C prototype is the one of C++. LOCATION is an expression for the position of the callback, (file line
  ;; column) or #f. The types are the C++ types:
  ;;   arguments  uptr, int, ... (any type of foreign-callable), and
  ;;     type-range     a TypeRange by value (16 bytes): the procedure gets the list of the types
  ;;   results    void, uptr, int, unsigned-8 (a bool), and the types that C++ answers by value:
  ;;     object         a class of one pointer (Type, TypeAttr, StringAttr, ...): the procedure answers the pointer
  ;;     logical-result an llvm::LogicalResult (one byte, 1 for success)
  ;;     walk-result    an mlir::WalkResult (4 bytes, constants in (mlir Support WalkResult))
  ;;     range          an ArrayRef or an OperandRange: the procedure answers (data . size)
  ;; Windows x64 answers a class with a constructor (object, logical-result, walk-result) through the place that
  ;; the caller gives, a pointer before the other arguments: the function writes its answer there, and answers
  ;; the pointer. SlotAbiTest (unittests/Crest/InterfaceTest.cpp) calls a callable of each type through a
  ;; function pointer of the exact type, on Linux and Windows.
  (define-syntax %%make-code
    (lambda (stx)
      (syntax-case stx ()
        [(_ (type ...) result-type procedure location)
         (let* ([types (syntax->list #'(type ...))]
                [formals (generate-temporaries types)]
                [c-types (map (lambda (k)
                                (if (eq? (syntax->datum k) 'type-range) #'(& %%SlotRange) k))
                              types)]
                [arguments (map (lambda (k formal)
                                  (if (eq? (syntax->datum k) 'type-range)
                                      #`(%%type-range->list (ftype-ref %%SlotRange (data) #,formal)
                                                            (ftype-ref %%SlotRange (size) #,formal))
                                      formal))
                                types formals)]
                ;; a class answered by value: the size of its answer, and its C type where it is a register
                [class-answer
                 (lambda (size linux-c-type)
                   #`(if (%%windows?)
                         (foreign-callable
                          (lambda (answer #,@formals)
                            (foreign-set! '#,size answer 0 (p #,@arguments))
                            answer)
                          (uptr #,@c-types) uptr)
                         (foreign-callable (lambda (#,@formals) (p #,@arguments))
                                           (#,@c-types) #,linux-c-type)))])
           #`(let ([p (%%guard-for-result 'result-type procedure location)])
               #,(case (syntax->datum #'result-type)
                   [(void uptr int unsigned-8)
                    #`(foreign-callable (lambda (#,@formals) (p #,@arguments)) (#,@c-types) result-type)]
                   [(object) (class-answer #'uptr #'uptr)]
                   [(logical-result) (class-answer #'unsigned-8 #'unsigned-8)]
                   [(walk-result) (class-answer #'unsigned-32 #'int)]
                   [(range)
                    #`(foreign-callable
                       (lambda (answer #,@formals)
                         (let ([pair (p #,@arguments)])
                           (ftype-set! %%SlotRange (data) answer (car pair))
                           (ftype-set! %%SlotRange (size) answer (cdr pair))))
                       (#,@c-types) (& %%SlotRange))]
                   [else
                    (syntax-violation 'crest-make-static-c-callable
                                      "unknown result type of a callable" stx #'result-type)])))])))

  ;; ---- the guard of a callable (plan 05) ----------------------------------------------------------
  ;;
  ;; MLIR declares the prototype, and it has no room for an error, so when the procedure raises the guard
  ;; reports "<file>:<line>:<column>: <who>: <why>" (the Scheme position of the callback, then the error):
  ;;   result void       nothing can say "failed": the process ends with the text (llvm::report_fatal_error)
  ;;   any other result  mlir::emitError with the text, in (current-MLIRContext), and the zero of the C
  ;;                     result type is answered so that the function can return; with no current context
  ;;                     nothing can be emitted, and the process ends with the text
  ;; LOCATION is (file line column), read when the macro expands, or #f.

  ;; The guard of a callable by the type of its result: void has no place for an error, a range answers
  ;; (data . size), the others are numbers.
  (define (%%guard-for-result result-type procedure location)
    (case result-type
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

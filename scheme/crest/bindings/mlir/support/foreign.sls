#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;; Mirrors lib/Bindings/Support/Result.h (CREST-specific, no MLIR counterpart).
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support foreign) — crest-foreign-procedure: how Scheme calls a binding that answers an error as a
;; value.
;;
;; A C++ binding answers a Scheme object: the value, or on failure the pair (who . why), who a symbol and
;; why a string (scheme_error in lib/Bindings/Support/Result.h). crest-foreign-procedure has the shape of
;; foreign-procedure, calls the symbol for a `scheme-object`, and raises the error here, in Scheme, after the
;; C++ call has returned: no error crosses a C function, so no C++ destructor is skipped and Chez keeps
;; nothing for an escaped call.
;;
;; It also does two jobs for the callbacks that C++ runs inside the binding (scheme/crest/callback.sls, which
;; never raise): it counts the bindings on the stack, so that C++ knows whether somebody will raise the error
;; of a callback (failIfUnanswered), and when the binding returns it raises that error, if there is one.
;;
;;   (crest-foreign-procedure "mlir::Block::getArgument" (uptr int) uptr)
;;
;; The declared result only tells how to read the answer: `boolean` accepts a Scheme boolean or 0/1 (a C++
;; `int` that stands for a boolean); every other result is the value as it came.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support foreign)
  (export crest-foreign-procedure
          %crest::error::set
          crest-callback-error-pending?)
  (import (chezscheme))

  ;; The error is a pair (who . why): a symbol and a string. No value that a binding answers looks like it.
  (define (%%error? x)
    (and (pair? x) (symbol? (car x)) (string? (cdr x))))

  (define (%%raise-error x)
    (let ([who (symbol->string (car x))])
      (error (if (string=? who "") #f who) (cdr x))))

  (define (%%boolean x)
    (if (boolean? x) x (not (eqv? x 0))))

  ;; The guard of a callable puts the text of an error here, for the binding that is running to raise.
  (define %crest::error::set
    (foreign-procedure "crest::error::set" (string string) void))

  (define %%take-error
    (foreign-procedure "crest::error::take" () scheme-object))

  ;; Is an error waiting in the slot? The flag is one byte at an address that C++ gives once.
  (define %%pending-flag-address
    ((foreign-procedure "crest::error::pendingFlag" () uptr)))

  (define (crest-callback-error-pending?)
    (not (zero? (foreign-ref 'unsigned-8 %%pending-flag-address 0))))

  ;; The number of bindings on the stack: an int at an address that C++ gives once.
  (define %%depth-address
    ((foreign-procedure "crest::error::depthAddress" () uptr)))

  (define (%%depth-add! n)
    (foreign-set! 'int %%depth-address 0 (+ (foreign-ref 'int %%depth-address 0) n)))

  (define-syntax crest-foreign-procedure
    (lambda (stx)
      (syntax-case stx ()
        [(_ name (type ...) result)
         (with-syntax ([(argument ...) (generate-temporaries #'(type ...))]
                       [read (case (syntax->datum #'result)
                               [(boolean) #'%%boolean]
                               [else #'values])])
           #'(let ([procedure (foreign-procedure name (type ...) scheme-object)])
               (lambda (argument ...)
                 (%%depth-add! 1)
                 (let ([answer (procedure argument ...)])
                   (%%depth-add! -1)
                   (cond
                    [(crest-callback-error-pending?) (%%raise-error (%%take-error))]
                    [(%%error? answer) (%%raise-error answer)]
                    [else (read answer)])))))])))

  ) ;; end library (mlir support foreign)

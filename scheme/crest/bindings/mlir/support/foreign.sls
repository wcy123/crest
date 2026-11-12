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
;; value (plans/04-errors-are-values.md).
;;
;; The C++ function registered with register_binding (lib/Bindings/Support/Result.h) answers a Scheme
;; object: the value, or the error object (#!eof who . message). crest-foreign-procedure has the shape of
;; foreign-procedure, calls the symbol for a `scheme-object`, and raises the error object here, in
;; Scheme, after the C++ call has returned: no error crosses a C function, so no C++ destructor is
;; skipped and Chez keeps nothing for an escaped call.
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

  ;; The error object is a pair whose first element is the eof object.
  (define (%%error-object? x)
    (and (pair? x) (eof-object? (car x))))

  ;; who is the name of the binding, message the text; both are strings.
  (define (%%raise-error-object x)
    (error (if (string=? (cadr x) "") #f (cadr x)) (cddr x)))

  (define (%%boolean x)
    (if (boolean? x) x (not (eqv? x 0))))

  ;; The guard of a callable puts the text of an error here, for the next binding that returns to answer.
  (define %crest::error::set
    (foreign-procedure "crest::error::set" (string string) void))

  ;; Is an error waiting in the slot? The flag is one byte at an address that C++ gives once.
  (define %%pending-flag-address
    ((foreign-procedure "crest::error::pendingFlag" () uptr)))

  (define (crest-callback-error-pending?)
    (not (zero? (foreign-ref 'unsigned-8 %%pending-flag-address 0))))

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
                 (let ([answer (procedure argument ...)])
                   (if (%%error-object? answer)
                       (%%raise-error-object answer)
                       (read answer))))))])))

  ) ;; end library (mlir support foreign)

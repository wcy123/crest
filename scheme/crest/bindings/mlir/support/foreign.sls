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
;; It also raises the error of a callback that C++ ran inside the binding (scheme/crest/callback.sls, which
;; never raises: it stores the error in C++ and answers the zero value), when the binding returns.
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

  ;; The guard of a callable puts the text of an error here, for the binding that is running to raise.
  (define %crest::error::set
    (foreign-procedure "crest::error::set" (string string) void))

  ;; The error in the slot, (who . why), or #f.
  (define %%take-error
    (foreign-procedure "crest::error::take" () scheme-object))

  ;; Is an error waiting in the slot?
  (define crest-callback-error-pending?
    (foreign-procedure "crest::error::pending" () boolean))

  ;; The answer of a binding, or its error: the one of a callback that ran inside it, if there is one,
  ;; else the binding's own, a pair (who . why) of a symbol and a string. No value that a binding
  ;; answers looks like that pair.
  (define (%%result answer)
    (let ([failure (or (%%take-error)
                       (and (pair? answer) (symbol? (car answer)) (string? (cdr answer)) answer))])
      (if failure
          (let ([who (symbol->string (car failure))])
            (error (if (string=? who "") #f who) (cdr failure)))
          answer)))

  (define-syntax crest-foreign-procedure
    (lambda (stx)
      (syntax-case stx ()
        [(_ name (type ...) result)
         (with-syntax ([(argument ...) (generate-temporaries #'(type ...))]
                       [read (case (syntax->datum #'result)
                               [(boolean) #'(lambda (x) (if (boolean? x) x (not (eqv? x 0))))]
                               [else #'values])])
           #'(let ([procedure (foreign-procedure name (type ...) scheme-object)])
               (lambda (argument ...)
                 (read (%%result (procedure argument ...))))))])))

  ) ;; end library (mlir support foreign)

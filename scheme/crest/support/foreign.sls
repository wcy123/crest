#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;; Mirrors lib/Bindings/Support/Result.h (CREST-specific, no MLIR counterpart).
;;===----------------------------------------------------------------------===;;
;;
;; (crest support foreign) — crest-foreign-procedure: how Scheme calls a binding that answers an error as a
;; value.
;;
;; A C++ binding answers a Scheme object: the value, or on failure the pair (who . why), who a symbol and
;; why a string (scheme_error in lib/Bindings/Support/Result.h). crest-foreign-procedure has the shape of
;; foreign-procedure, calls the symbol for a `scheme-object`, and raises the error here, in Scheme, after the
;; C++ call has returned: no error crosses a C function, so no C++ destructor is skipped and Chez keeps
;; nothing for an escaped call. The answer is the value as it came: the declared result type is only
;; documentation of what the answer is (a number, #t or #f, a list, ...).
;;
;;   (crest-foreign-procedure "mlir::Block::getArgument" (uptr int) uptr)
;;
;;===----------------------------------------------------------------------===;;

(library (crest support foreign)
  (export crest-foreign-procedure)
  (import (chezscheme))

  (define (%%result answer)
    (let ([failure (and (pair? answer) (symbol? (car answer)) (string? (cdr answer)) answer)])
      (if failure
          (let ([who (symbol->string (car failure))])
            (error who (cdr failure)))
          answer)))

  (define-syntax crest-foreign-procedure
    (lambda (stx)
      (syntax-case stx ()
        [(_ name (type ...) result)
         (with-syntax ([(argument ...) (generate-temporaries #'(type ...))])
           #'(let ([procedure (foreign-procedure name (type ...) scheme-object)])
               (lambda (argument ...)
                 (%%result (procedure argument ...)))))])))

  ) ;; end library (crest support foreign)

#!r6rs
;; (begin-mlir-code) with no op-form and no expression has no value to return: an error of
;; expansion.
(library (passes empty-begin-mlir-code)
  (export pass-entry-point)
  (import (except (rnrs) =) (crest))

  (define (%%build)
    (begin-mlir-code))

  (define-pass-entry-point (module-op) module-op)

  ) ;; end library

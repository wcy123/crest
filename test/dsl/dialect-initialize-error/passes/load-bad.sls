#!r6rs
;; A pass that loads the dialect of bad-dialect.sls.
(library (passes load-bad)
  (export pass-entry-point)
  (import (only (crest pass) define-pass-entry-point)
          (chezscheme)
          (mlir IR Operation)
          (mlir IR MLIRContext))

  (define-pass-entry-point (module)
    (let ([ctx (mlir::Operation::getContext module)])
      (guard (c [#t (display "caught: ")
                    (display (condition-message c))
                    (newline)])
        (mlir::MLIRContext::getOrLoadDialect ctx "badd")
        (display "not raised")
        (newline)))))

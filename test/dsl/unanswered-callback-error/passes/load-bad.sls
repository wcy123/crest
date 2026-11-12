#!r6rs
;; A pass that loads the dialect of bad-dialect.sls and catches the error.
(library (passes load-bad)
  (export run-pass)
  (import (chezscheme)
          (mlir IR Operation)
          (mlir IR MLIRContext))

  (define (run-pass module)
    (let ([ctx (mlir::Operation::getContext module)])
      (guard (c [#t (display "caught: ")
                    (display (condition-message c))
                    (newline)])
        (mlir::MLIRContext::getOrLoadDialect ctx "badd")
        (display "not raised")
        (newline)))))

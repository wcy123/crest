;; Loads the nosymbol dialect into a context, which registers its ops.
(import (chezscheme)
        (crest dialect)
        (mlir IR MLIRContext)
        (mlir IR DialectRegistry))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
    (load-scheme-dialect! ctx "nosymbol" "passes/function-without-symbol")
    (display "loaded\n")))

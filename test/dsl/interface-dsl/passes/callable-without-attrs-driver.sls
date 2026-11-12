;; Loads the noattrs dialect into a context, which registers its ops.
(import (chezscheme)
        (crest dialect)
        (mlir IR MLIRContext)
        (mlir IR DialectRegistry))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
    (load-scheme-dialect! ctx "noattrs" "passes/callable-without-attrs")
    (display "loaded\n")))

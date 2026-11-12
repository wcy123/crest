;; Loads the nocallable dialect into a context, which registers its ops.
(import (chezscheme)
        (crest dialect)
        (mlir IR MLIRContext)
        (mlir IR DialectRegistry))

(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
    (load-scheme-dialect! ctx "nocallable" "passes/function-without-callable")
    (display "loaded\n")))

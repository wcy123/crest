;; Loads the nosymbol dialect into a context, which registers its ops.
(import (chezscheme)
        (crest dialect)
        (mlir IR MLIRContext))

(let ([ctx (mlir::MLIRContext::new)])
  (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
  (load-scheme-dialect! ctx "nosymbol" "passes/function-without-symbol")
  (display "loaded\n"))

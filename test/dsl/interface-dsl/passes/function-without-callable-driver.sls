;; Loads the nocallable dialect into a context, which registers its ops.
(import (chezscheme)
        (crest dialect)
        (mlir IR MLIRContext))

(let ([ctx (mlir::MLIRContext::new)])
  (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
  (load-scheme-dialect! ctx "nocallable" "passes/function-without-callable")
  (display "loaded\n"))

;; Loads the noattrs dialect into a context, which registers its ops.
(import (chezscheme)
        (crest dialect)
        (mlir IR MLIRContext))

(let ([ctx (mlir::MLIRContext::new)])
  (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
  (load-scheme-dialect! ctx "noattrs" "passes/callable-without-attrs")
  (display "loaded\n"))

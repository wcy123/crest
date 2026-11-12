;; Loads the nosymbol dialect into a context, which registers its ops.
(import (chezscheme)
        (crest dialect)
        (mlir IR MLIRContext)
        (mlir IR DialectRegistry))

;; LEAK WARNING: what this makes (the context, the module, the builder) lives in a with- scope and is
;; freed when the scope ends. A raw MLIRContext::new, ModuleOp::create or parseSourceFile result that is
;; never freed leaked, and exit inside a scope skips the cleanup: raise, and exit at the top (%%quit).
(with-DialectRegistry reg ()
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
    (load-scheme-dialect! ctx "nosymbol" "passes/function-without-symbol")
    (display "loaded\n")))

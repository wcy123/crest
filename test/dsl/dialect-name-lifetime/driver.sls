;; scheme-mlir driver: loads the dt dialect of test/dsl/dialect-types with load-scheme-dialect!, parses the
;; input and prints it. The printed text has the name of the dialect in `!dt.pair<...>`.
(import (rnrs)
        (only (chezscheme) command-line-arguments)
        (only (crest dialect) load-scheme-dialect!)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation) (mlir IR OwningOpRef)
        (mlir Dialect Func IR FuncOps))

(with-DialectRegistry reg ()
  (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::getOrLoadDialect ctx "func")
    (load-scheme-dialect! ctx "dt" "passes/type-dialect")
    ;; The strings of earlier work are garbage now: make the allocator reuse and overwrite them.
    (do ([i 0 (+ i 1)]) ((= i 2000)) (make-string 40 #\x))
    (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx (car (command-line-arguments)))
      (display (mlir::Operation::print module))
      (newline))))

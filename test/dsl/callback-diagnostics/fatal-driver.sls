;; scheme-mlir driver: a callback whose C++ result is void (the thunk of modifyOpInPlace) raises an error. MLIR has no
;; place for the error in a void prototype, so the process ends with the text of the error.
(import (chezscheme)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef)
        (mlir Dialect Func IR FuncOps)
        (passes errors))

(define path (car (command-line-arguments)))

(with-DialectRegistry reg ()
  (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
  (with-MLIRContext ctx (reg)
    (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
    (mlir::MLIRContext::getOrLoadDialect ctx "func")
    (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx path)
      (modify-raises module)
      (display "not reached\n"))))

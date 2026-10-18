;; Lower Toy AST to MLIR
;; Mirrors mlir/examples/toy/Ch1/toyc.cpp — MLIRGen
(library (toy ch1 codegen)
  (export toy-codegen)
  (import (chezscheme)
          (toy ch1 ast)
          (mlir IR MLIRContext)
          (mlir IR Builders)
          (mlir IR Location))

  ;; Lower a Toy module AST to an MLIR module op.
  ;; Returns an mlir::ModuleOp uptr.
  (define (toy-codegen ctx toy-module)
    ;; TODO: walk toy-module, emit MLIR ops
    (error "toy-codegen" "not yet implemented")))

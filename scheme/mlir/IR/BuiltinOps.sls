;; Mirrors mlir/IR/BuiltinOps.h
(library (mlir IR BuiltinOps)
  (export
    mlir::ModuleOp::create
    mlir::ModuleOp::getOperation
    mlir::ModuleOp::getBody)
  (import (rnrs) (mlir IR BuiltinOps ffi))

  (define mlir::ModuleOp::create    %mlir::ModuleOp::create)
  (define mlir::ModuleOp::getOperation %mlir::ModuleOp::getOperation)
  (define mlir::ModuleOp::getBody   %mlir::ModuleOp::getBody)
  )

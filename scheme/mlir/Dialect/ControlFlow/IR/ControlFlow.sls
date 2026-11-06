#!r6rs
;; Mirrors mlir/Dialect/ControlFlow/IR/ControlFlow.h
(library (mlir Dialect ControlFlow IR ControlFlow)
  (export mlir::DialectRegistry::insert<mlir::cf::ControlFlowDialect>)
  (import (rnrs) (mlir Dialect ControlFlow IR ControlFlow ffi))
  (define mlir::DialectRegistry::insert<mlir::cf::ControlFlowDialect>
    %mlir::DialectRegistry::insert<mlir::cf::ControlFlowDialect>))

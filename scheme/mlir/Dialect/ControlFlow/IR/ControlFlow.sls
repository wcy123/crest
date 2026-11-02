#!r6rs
;; Mirrors mlir/Dialect/ControlFlow/IR/ControlFlow.h
(library (mlir Dialect ControlFlow IR ControlFlow)
  (export mlir::cf::ControlFlowDialect)
  (import (rnrs) (mlir Dialect ControlFlow IR ControlFlow ffi))
  (define mlir::cf::ControlFlowDialect
    %mlir::cf::ControlFlowDialect))

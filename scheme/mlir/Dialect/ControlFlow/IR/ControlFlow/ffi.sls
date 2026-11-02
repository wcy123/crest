#!r6rs
;; Mirrors mlir/Dialect/ControlFlow/IR/ControlFlow.h
(library (mlir Dialect ControlFlow IR ControlFlow ffi)
  (export %mlir::cf::ControlFlowDialect)
  (import (chezscheme))
  (define %mlir::cf::ControlFlowDialect
    (foreign-procedure "mlir::cf::ControlFlowDialect" (uptr) void)))

#!r6rs
;; Mirrors mlir/Dialect/ControlFlow/IR/ControlFlow.h
(library (mlir Dialect ControlFlow IR ControlFlow ffi)
  (export %mlir::DialectRegistry::insert<mlir::cf::ControlFlowDialect>)
  (import (chezscheme))
  (define %mlir::DialectRegistry::insert<mlir::cf::ControlFlowDialect>
    (foreign-procedure "mlir::DialectRegistry::insert<mlir::cf::ControlFlowDialect>" (uptr) void)))

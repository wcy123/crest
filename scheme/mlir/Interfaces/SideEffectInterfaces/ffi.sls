#!r6rs
;; Mirrors mlir/Interfaces/SideEffectInterfaces.h
(library (mlir Interfaces SideEffectInterfaces ffi)
  (export %mlir::MemoryEffectOpInterface
          %mlir::ConditionallySpeculatable)
  (import (chezscheme))

  (define %mlir::MemoryEffectOpInterface
    (foreign-procedure "mlir::MemoryEffectOpInterface" (string) void))

  (define %mlir::ConditionallySpeculatable
    (foreign-procedure "mlir::ConditionallySpeculatable" (string) void))

  ) ;; end library (mlir Interfaces SideEffectInterfaces ffi)

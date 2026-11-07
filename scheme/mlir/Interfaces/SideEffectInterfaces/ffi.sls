#!r6rs
;; Mirrors mlir/Interfaces/SideEffectInterfaces.h
(library (mlir Interfaces SideEffectInterfaces ffi)
  (export %mlir::MemoryEffectOpInterface
          %mlir::ConditionallySpeculatable)
  (import (chezscheme))

  (define %mlir::MemoryEffectOpInterface
    (foreign-procedure "mlir::MemoryEffectOpInterface" (scheme-object) void))

  (define %mlir::ConditionallySpeculatable
    (foreign-procedure "mlir::ConditionallySpeculatable" (scheme-object) void))

  ) ;; end library (mlir Interfaces SideEffectInterfaces ffi)

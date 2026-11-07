#!r6rs
;; Mirrors mlir/Interfaces/SideEffectInterfaces.h
(library (mlir Interfaces SideEffectInterfaces)
  (export mlir::MemoryEffectOpInterface
          mlir::ConditionallySpeculatable)
  (import (rnrs)
          (mlir Interfaces SideEffectInterfaces ffi))

  (define mlir::MemoryEffectOpInterface %mlir::MemoryEffectOpInterface)
  (define mlir::ConditionallySpeculatable %mlir::ConditionallySpeculatable)

  ) ;; end library (mlir Interfaces SideEffectInterfaces)

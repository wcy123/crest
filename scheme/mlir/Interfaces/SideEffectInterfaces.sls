#!r6rs
;; Mirrors mlir/Interfaces/SideEffectInterfaces.h
(library (mlir Interfaces SideEffectInterfaces)
  (export mlir::MemoryEffectOpInterface
          mlir::ConditionallySpeculatable)
  (import (rnrs)
          (mlir Interfaces SideEffectInterfaces ffi))

  ;; dispatcher: made by define-op for the op's :interfaces entry; 'operation_name answers the
  ;; op's name. Neither interface has a method that Scheme implements: the op has no memory
  ;; effects and may be speculated.
  (define (mlir::MemoryEffectOpInterface dispatcher)
    (%mlir::MemoryEffectOpInterface (dispatcher 'operation_name)))

  (define (mlir::ConditionallySpeculatable dispatcher)
    (%mlir::ConditionallySpeculatable (dispatcher 'operation_name)))

  ) ;; end library (mlir Interfaces SideEffectInterfaces)

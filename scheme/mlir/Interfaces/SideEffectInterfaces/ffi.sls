#!r6rs
;; Mirrors mlir/Interfaces/SideEffectInterfaces.h
(library (mlir Interfaces SideEffectInterfaces ffi)
  (export %mlir::MemoryEffectOpInterface::getInterfaceID
          %mlir::ConditionallySpeculatable::getInterfaceID)
  (import (chezscheme))

  ;; () -> uptr: the TypeID of the interface, as the address that the TypeID wraps.
  (define %mlir::MemoryEffectOpInterface::getInterfaceID
    (foreign-procedure "mlir::MemoryEffectOpInterface::getInterfaceID" () uptr))

  (define %mlir::ConditionallySpeculatable::getInterfaceID
    (foreign-procedure "mlir::ConditionallySpeculatable::getInterfaceID" () uptr))

  ) ;; end library (mlir Interfaces SideEffectInterfaces ffi)

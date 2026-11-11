#!r6rs
;; Mirrors mlir/Interfaces/SideEffectInterfaces.h
(library (mlir Interfaces SideEffectInterfaces ffi)
  (export %mlir::MemoryEffectOpInterface::getInterfaceID
          %mlir::ConditionallySpeculatable::getInterfaceID
          %crest::MemoryEffectOpInterface::noEffects)
  (import (chezscheme))

  ;; () -> uptr: the TypeID of the interface, as the address that the TypeID wraps.
  (define %mlir::MemoryEffectOpInterface::getInterfaceID
    (foreign-procedure "mlir::MemoryEffectOpInterface::getInterfaceID" () uptr))

  (define %mlir::ConditionallySpeculatable::getInterfaceID
    (foreign-procedure "mlir::ConditionallySpeculatable::getInterfaceID" () uptr))

  ;; () -> uptr: the address of the C function that stands for "no memory effects".
  (define %crest::MemoryEffectOpInterface::noEffects
    (foreign-procedure "crest::MemoryEffectOpInterface::noEffects" () uptr))

  ) ;; end library (mlir Interfaces SideEffectInterfaces ffi)

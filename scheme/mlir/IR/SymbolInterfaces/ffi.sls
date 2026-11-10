#!r6rs
;; Mirrors mlir/IR/SymbolInterfaces.h
(library (mlir IR SymbolInterfaces ffi)
  (export %mlir::SymbolOpInterface::getInterfaceID
          %mlir::SymbolOpInterface::getNameAttr
          %mlir::SymbolOpInterface::setName)
  (import (chezscheme))

  ;; () -> uptr: the TypeID of the interface, as the address that the TypeID wraps.
  (define %mlir::SymbolOpInterface::getInterfaceID
    (foreign-procedure "mlir::SymbolOpInterface::getInterfaceID" () uptr))

  (define %mlir::SymbolOpInterface::getNameAttr
    (foreign-procedure "mlir::SymbolOpInterface::getNameAttr" (uptr) uptr))

  (define %mlir::SymbolOpInterface::setName
    (foreign-procedure "mlir::SymbolOpInterface::setName" (uptr uptr) void))

  ) ;; end library (mlir IR SymbolInterfaces ffi)

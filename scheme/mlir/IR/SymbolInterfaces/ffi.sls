#!r6rs
;; Mirrors mlir/IR/SymbolInterfaces.h
(library (mlir IR SymbolInterfaces ffi)
  (export %mlir::SymbolOpInterface
          %mlir::SymbolOpInterface::getNameAttr
          %mlir::SymbolOpInterface::setName)
  (import (chezscheme))

  (define %mlir::SymbolOpInterface
    (foreign-procedure "mlir::SymbolOpInterface" (scheme-object) void))

  (define %mlir::SymbolOpInterface::getNameAttr
    (foreign-procedure "mlir::SymbolOpInterface::getNameAttr" (uptr) uptr))

  (define %mlir::SymbolOpInterface::setName
    (foreign-procedure "mlir::SymbolOpInterface::setName" (uptr uptr) void))

  ) ;; end library (mlir IR SymbolInterfaces ffi)

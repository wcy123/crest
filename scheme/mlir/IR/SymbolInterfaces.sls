#!r6rs
;; Mirrors mlir/IR/SymbolInterfaces.h
(library (mlir IR SymbolInterfaces)
  (export mlir::SymbolOpInterface
          mlir::SymbolOpInterface::getNameAttr
          mlir::SymbolOpInterface::setName)
  (import (rnrs)
          (mlir IR SymbolInterfaces ffi))

  (define mlir::SymbolOpInterface %mlir::SymbolOpInterface)
  (define mlir::SymbolOpInterface::getNameAttr %mlir::SymbolOpInterface::getNameAttr)
  (define mlir::SymbolOpInterface::setName %mlir::SymbolOpInterface::setName)

  ) ;; end library (mlir IR SymbolInterfaces)

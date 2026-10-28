#!r6rs
;; Mirrors mlir/IR/SymbolInterfaces.h
(library (mlir IR SymbolInterfaces)
  (export mlir::SymbolOpInterface
          mlir::SymbolOpInterface::getNameAttr
          mlir::SymbolOpInterface::setName)
  (import (rnrs)
          (mlir IR SymbolInterfaces ffi))

  (define mlir::SymbolOpInterface %mlir::SymbolOpInterface)

  (define (mlir::SymbolOpInterface::getNameAttr op)
    (%mlir::SymbolOpInterface::getNameAttr op))

  (define (mlir::SymbolOpInterface::setName op name)
    (%mlir::SymbolOpInterface::setName op name))

  ) ;; end library (mlir IR SymbolInterfaces)

#!r6rs
;; Mirrors mlir/IR/SymbolInterfaces.h
(library (mlir IR SymbolInterfaces)
  (export mlir::SymbolOpInterface
          mlir::SymbolOpInterface::getNameAttr
          mlir::SymbolOpInterface::setName)
  (import (rnrs)
          (mlir IR SymbolInterfaces ffi))

  ;; dispatcher: made by define-op for the op's :interfaces entry; 'operation_name answers the
  ;; op's name. The interface has no method that Scheme implements.
  (define (mlir::SymbolOpInterface dispatcher)
    (%mlir::SymbolOpInterface (dispatcher 'operation_name)))

  (define (mlir::SymbolOpInterface::getNameAttr op)
    (%mlir::SymbolOpInterface::getNameAttr op))

  (define (mlir::SymbolOpInterface::setName op name)
    (%mlir::SymbolOpInterface::setName op name))

  ) ;; end library (mlir IR SymbolInterfaces)

#!r6rs
;; Mirrors mlir/IR/SymbolInterfaces.h
(library (mlir IR SymbolInterfaces)
  (export mlir::SymbolOpInterface
          mlir::SymbolOpInterface::getInterfaceID
          mlir::SymbolOpInterface::getNameAttr
          mlir::SymbolOpInterface::setName)
  (import (chezscheme)
          (crest callback)
          (mlir IR SymbolInterfaces ffi))

  ;; The head of an entry of the :interfaces clause of define-op (see
  ;; (mlir Interfaces InferTypeOpInterface)): the pair of the TypeID of the interface and the
  ;; dispatcher of its clauses. The interface has no method that Scheme implements.
  (define-syntax mlir::SymbolOpInterface
    (lambda (stx)
      (syntax-case stx ()
        [(_) #'(cons (mlir::SymbolOpInterface::getInterfaceID)
                     (crest-callback-entry-dispatcher '()))]
        [(_ clause ...)
         (syntax-violation ':interfaces "mlir::SymbolOpInterface takes no method clauses" stx)])))

  (define mlir::SymbolOpInterface::getInterfaceID
    %mlir::SymbolOpInterface::getInterfaceID)

  (define (mlir::SymbolOpInterface::getNameAttr op)
    (%mlir::SymbolOpInterface::getNameAttr op))

  (define (mlir::SymbolOpInterface::setName op name)
    (%mlir::SymbolOpInterface::setName op name))

  ) ;; end library (mlir IR SymbolInterfaces)

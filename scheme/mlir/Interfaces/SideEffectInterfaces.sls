#!r6rs
;; Mirrors mlir/Interfaces/SideEffectInterfaces.h
(library (mlir Interfaces SideEffectInterfaces)
  (export mlir::MemoryEffectOpInterface
          mlir::ConditionallySpeculatable
          mlir::MemoryEffectOpInterface::getInterfaceID
          mlir::ConditionallySpeculatable::getInterfaceID)
  (import (chezscheme)
          (crest callback)
          (mlir Interfaces SideEffectInterfaces ffi))

  ;; The heads of entries of the :interfaces clause of define-op (see
  ;; (mlir Interfaces InferTypeOpInterface)): the pair of the TypeID of the interface and the
  ;; dispatcher of its clauses. Neither interface has a method that Scheme implements: the op has no
  ;; memory effects and may be speculated.
  (define-syntax mlir::MemoryEffectOpInterface
    (lambda (stx)
      (syntax-case stx ()
        [(_) #'(cons (mlir::MemoryEffectOpInterface::getInterfaceID)
                     (crest-callback-entry-dispatcher '()))]
        [(_ clause ...)
         (syntax-violation ':interfaces "mlir::MemoryEffectOpInterface takes no method clauses" stx)])))

  (define-syntax mlir::ConditionallySpeculatable
    (lambda (stx)
      (syntax-case stx ()
        [(_) #'(cons (mlir::ConditionallySpeculatable::getInterfaceID)
                     (crest-callback-entry-dispatcher '()))]
        [(_ clause ...)
         (syntax-violation ':interfaces "mlir::ConditionallySpeculatable takes no method clauses" stx)])))

  (define mlir::MemoryEffectOpInterface::getInterfaceID
    %mlir::MemoryEffectOpInterface::getInterfaceID)

  (define mlir::ConditionallySpeculatable::getInterfaceID
    %mlir::ConditionallySpeculatable::getInterfaceID)

  ) ;; end library (mlir Interfaces SideEffectInterfaces)

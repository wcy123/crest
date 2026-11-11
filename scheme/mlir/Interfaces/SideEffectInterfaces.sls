#!r6rs
;; Mirrors mlir/Interfaces/SideEffectInterfaces.h
(library (mlir Interfaces SideEffectInterfaces)
  (export mlir::MemoryEffectOpInterface
          mlir::ConditionallySpeculatable
          mlir::MemoryEffectOpInterface::getInterfaceID
          mlir::ConditionallySpeculatable::getInterfaceID)
  (import (chezscheme)
          (crest callback)
          (for (crest interface) expand)
          (mlir Interfaces SideEffectInterfaces ffi))

  ;; The heads of entries of the :interfaces clause of define-op (see (crest interface)): the pair
  ;; of the TypeID of the interface and the dispatcher of its clauses. MLIR has no default for
  ;; either method (the op class, or a trait such as pure, gives it), so the op gives it:
  ;;
  ;;   (mlir::MemoryEffectOpInterface (getEffects :none))
  ;;     the op has no memory effects: a C function that CREST ships. A clause
  ;;     (getEffects (op effects) body ...) gets the place for the effects as a number; Scheme has
  ;;     no way yet to add an effect to it.
  ;;   (mlir::ConditionallySpeculatable (getSpeculatability :always))
  ;;     the op can be speculated. A clause (getSpeculatability (op) body ...) answers 0 (not
  ;;     speculatable), 1 (speculatable) or 2 (speculatable if the operations in its regions are).
  ;;
  ;; The trait `pure` gives an op both answers, and a clause replaces them.
  (define (%%always op) 1)

  (define-syntax mlir::MemoryEffectOpInterface
    (lambda (stx)
      (op-interface-expand
       stx 'mlir::MemoryEffectOpInterface #'(mlir::MemoryEffectOpInterface::getInterfaceID)
       #'((getEffects (uptr uptr) void #f #f
                      ((:none cpp (%crest::MemoryEffectOpInterface::noEffects))))))))

  (define-syntax mlir::ConditionallySpeculatable
    (lambda (stx)
      (op-interface-expand
       stx 'mlir::ConditionallySpeculatable #'(mlir::ConditionallySpeculatable::getInterfaceID)
       #'((getSpeculatability (uptr) int #f #f ((:always scheme %%always)))))))

  (define mlir::MemoryEffectOpInterface::getInterfaceID
    %mlir::MemoryEffectOpInterface::getInterfaceID)

  (define mlir::ConditionallySpeculatable::getInterfaceID
    %mlir::ConditionallySpeculatable::getInterfaceID)

  ) ;; end library (mlir Interfaces SideEffectInterfaces)

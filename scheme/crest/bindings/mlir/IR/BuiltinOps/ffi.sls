;; Mirrors mlir/IR/BuiltinOps.h
(library (mlir IR BuiltinOps ffi)
  (export
    %mlir::ModuleOp::create
    %mlir::ModuleOp::getOperation
    %mlir::ModuleOp::getBody)
  (import (rnrs)
          (mlir support foreign) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::ModuleOp::create — create an empty module op at the given location.
  ;; @param loc  mlir::Location opaque pointer uptr
  ;; @return     mlir::Operation* opaque pointer uptr (the module op's underlying operation)
  (define %mlir::ModuleOp::create
    (crest-foreign-procedure "mlir::ModuleOp::create" (uptr) uptr))

  ;; @brief mlir::ModuleOp::getOperation — identity; create already returns Operation*.
  ;; @param op   mlir::Operation* opaque pointer uptr
  ;; @return     same uptr
  (define %mlir::ModuleOp::getOperation
    (crest-foreign-procedure "mlir::ModuleOp::getOperation" (uptr) uptr))

  ;; @brief mlir::ModuleOp::getBody — return the single body block of the module.
  ;; @param op   mlir::Operation* opaque pointer uptr (the module op)
  ;; @return     mlir::Block* opaque pointer uptr
  (define %mlir::ModuleOp::getBody
    (crest-foreign-procedure "mlir::ModuleOp::getBody" (uptr) uptr))
  )

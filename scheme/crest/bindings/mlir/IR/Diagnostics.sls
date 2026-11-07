#!r6rs
;; Mirrors mlir/IR/Diagnostics.h
(library (mlir IR Diagnostics)
  (export mlir::emitError)
  (import (rnrs) (mlir IR Diagnostics ffi))

  ;; @brief mlir::emitError — report an error at a Location through the diagnostic engine.
  ;; @param loc      Location opaque pointer uptr
  ;; @param message  string
  (define mlir::emitError %mlir::emitError)

  ) ;; end library (mlir IR Diagnostics)

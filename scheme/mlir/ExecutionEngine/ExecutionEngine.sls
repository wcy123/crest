#!r6rs
;; Mirrors mlir/ExecutionEngine/ExecutionEngine.h
(library (mlir ExecutionEngine ExecutionEngine)
  (export mlir::ExecutionEngine::create
          mlir::ExecutionEngine::invoke
          with-ExecutionEngine)
  (import (rnrs)
          (mlir ExecutionEngine ExecutionEngine ffi)
          (only (mlir support CrestObject) with-CrestObject))
  ;; (create module) or (create module opt-level): JIT-compile with LLVM's optimizing pipeline at
  ;; opt-level 0 (default) to 3; 0 is returned when the engine cannot be created.
  (define mlir::ExecutionEngine::create
    (case-lambda
     [(module)           (%mlir::ExecutionEngine::create module 0)]
     [(module opt-level) (%mlir::ExecutionEngine::create module opt-level)]))
  (define mlir::ExecutionEngine::invoke %mlir::ExecutionEngine::invoke)
  (define-syntax with-ExecutionEngine
    (syntax-rules ()
      [(_ var (module-op) body ...)
       (with-CrestObject var (mlir::ExecutionEngine::create module-op) body ...)]
      [(_ var (module-op opt-level) body ...)
       (with-CrestObject var (mlir::ExecutionEngine::create module-op opt-level) body ...)])))

#!r6rs
;; Mirrors mlir/ExecutionEngine/ExecutionEngine.h
(library (mlir ExecutionEngine ExecutionEngine)
  (export mlir::ExecutionEngine::create
          mlir::ExecutionEngine::invoke
          with-ExecutionEngine)
  (import (rnrs)
          (mlir ExecutionEngine ExecutionEngine ffi)
          (only (mlir support CrestObject) with-CrestObject))
  (define mlir::ExecutionEngine::create %mlir::ExecutionEngine::create)
  (define mlir::ExecutionEngine::invoke %mlir::ExecutionEngine::invoke)
  (define-syntax with-ExecutionEngine
    (syntax-rules ()
      [(_ var (module-op) body ...)
       (with-CrestObject var (mlir::ExecutionEngine::create module-op) body ...)])))

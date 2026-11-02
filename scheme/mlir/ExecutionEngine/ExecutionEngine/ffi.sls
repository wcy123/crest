#!r6rs
;; Mirrors mlir/ExecutionEngine/ExecutionEngine.h
(library (mlir ExecutionEngine ExecutionEngine ffi)
  (export %mlir::ExecutionEngine::create
          %mlir::ExecutionEngine::invoke)
  (import (chezscheme))
  (define %mlir::ExecutionEngine::create
    (foreign-procedure "mlir::ExecutionEngine::create" (uptr) uptr))
  (define %mlir::ExecutionEngine::invoke
    (foreign-procedure "mlir::ExecutionEngine::invoke" (uptr string) int)))

#!r6rs
;; Mirrors mlir/ExecutionEngine/ExecutionEngine.h
(library (mlir ExecutionEngine ExecutionEngine ffi)
  (export %mlir::ExecutionEngine::create
          %mlir::ExecutionEngine::invoke)
  (import (chezscheme)
          (crest support foreign))
  (define %mlir::ExecutionEngine::create
    (crest-foreign-procedure "mlir::ExecutionEngine::create" (uptr int) uptr))
  (define %mlir::ExecutionEngine::invoke
    (crest-foreign-procedure "mlir::ExecutionEngine::invoke" (uptr string) int)))

#!r6rs
;; Mirrors mlir/IR/Diagnostics.h
(library (mlir IR Diagnostics ffi)
  (export %mlir::emitError)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %mlir::emitError
    (foreign-procedure "mlir::emitError" (uptr string) void))

  ) ;; end library (mlir IR Diagnostics ffi)

#!r6rs
;; Mirrors mlir/IR/Diagnostics.h
(library (mlir IR Diagnostics ffi)
  (export %mlir::emitError)
  (import (rnrs)
          (mlir support foreign) (only (chezscheme) foreign-procedure))

  (define %mlir::emitError
    (crest-foreign-procedure "mlir::emitError" (uptr string) void))

  ) ;; end library (mlir IR Diagnostics ffi)

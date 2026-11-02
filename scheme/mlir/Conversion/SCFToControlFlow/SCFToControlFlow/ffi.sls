#!r6rs
;; Mirrors mlir/Conversion/SCFToControlFlow/SCFToControlFlow.h
(library (mlir Conversion SCFToControlFlow SCFToControlFlow ffi)
  (export %mlir::populateSCFToControlFlowConversionPatterns)
  (import (chezscheme))
  (define %mlir::populateSCFToControlFlowConversionPatterns
    (foreign-procedure "mlir::populateSCFToControlFlowConversionPatterns" (uptr) void)))

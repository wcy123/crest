#!r6rs
;; Mirrors mlir/Conversion/SCFToControlFlow/SCFToControlFlow.h
(library (mlir Conversion SCFToControlFlow SCFToControlFlow ffi)
  (export %mlir::populateSCFToControlFlowConversionPatterns)
  (import (chezscheme)
          (mlir support foreign))
  (define %mlir::populateSCFToControlFlowConversionPatterns
    (crest-foreign-procedure "mlir::populateSCFToControlFlowConversionPatterns" (uptr) void)))

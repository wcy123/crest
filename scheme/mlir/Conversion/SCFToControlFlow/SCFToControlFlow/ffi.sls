#!r6rs
;; Mirrors mlir/Conversion/SCFToControlFlow/SCFToControlFlow.h
(library (mlir Conversion SCFToControlFlow SCFToControlFlow ffi)
  (export %mlir::populateSCFToControlFlowConversionPatterns)
  (import (chezscheme)
          (crest support foreign))
  (define %mlir::populateSCFToControlFlowConversionPatterns
    (crest-foreign-procedure "mlir::populateSCFToControlFlowConversionPatterns" (uptr) void)))

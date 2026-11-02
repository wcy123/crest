#!r6rs
;; Mirrors mlir/Conversion/SCFToControlFlow/SCFToControlFlow.h
(library (mlir Conversion SCFToControlFlow SCFToControlFlow)
  (export mlir::populateSCFToControlFlowConversionPatterns)
  (import (rnrs) (mlir Conversion SCFToControlFlow SCFToControlFlow ffi))
  (define mlir::populateSCFToControlFlowConversionPatterns
    %mlir::populateSCFToControlFlowConversionPatterns))

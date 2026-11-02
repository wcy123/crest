#!r6rs
;; Mirrors mlir/Conversion/AffineToStandard/AffineToStandard.h
(library (mlir Conversion AffineToStandard AffineToStandard)
  (export mlir::populateAffineToStdConversionPatterns)
  (import (rnrs) (mlir Conversion AffineToStandard AffineToStandard ffi))
  (define mlir::populateAffineToStdConversionPatterns
    %mlir::populateAffineToStdConversionPatterns))

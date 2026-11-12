#!r6rs
;; Mirrors mlir/Conversion/AffineToStandard/AffineToStandard.h
(library (mlir Conversion AffineToStandard AffineToStandard ffi)
  (export %mlir::populateAffineToStdConversionPatterns)
  (import (chezscheme)
          (mlir support foreign))
  (define %mlir::populateAffineToStdConversionPatterns
    (crest-foreign-procedure "mlir::populateAffineToStdConversionPatterns" (uptr) void)))

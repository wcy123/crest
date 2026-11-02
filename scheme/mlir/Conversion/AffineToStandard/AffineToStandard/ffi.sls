#!r6rs
;; Mirrors mlir/Conversion/AffineToStandard/AffineToStandard.h
(library (mlir Conversion AffineToStandard AffineToStandard ffi)
  (export %mlir::populateAffineToStdConversionPatterns)
  (import (chezscheme))
  (define %mlir::populateAffineToStdConversionPatterns
    (foreign-procedure "mlir::populateAffineToStdConversionPatterns" (uptr) void)))

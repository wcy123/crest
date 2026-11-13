#!r6rs
;; Mirrors mlir/Conversion/MemRefToLLVM/MemRefToLLVM.h
(library (mlir Conversion MemRefToLLVM MemRefToLLVM ffi)
  (export %mlir::populateFinalizeMemRefToLLVMConversionPatterns)
  (import (chezscheme)
          (crest support foreign))
  (define %mlir::populateFinalizeMemRefToLLVMConversionPatterns
    (crest-foreign-procedure "mlir::populateFinalizeMemRefToLLVMConversionPatterns" (uptr uptr) void)))

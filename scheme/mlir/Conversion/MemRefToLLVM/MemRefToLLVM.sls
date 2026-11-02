#!r6rs
;; Mirrors mlir/Conversion/MemRefToLLVM/MemRefToLLVM.h
(library (mlir Conversion MemRefToLLVM MemRefToLLVM)
  (export mlir::populateFinalizeMemRefToLLVMConversionPatterns)
  (import (rnrs) (mlir Conversion MemRefToLLVM MemRefToLLVM ffi))
  (define mlir::populateFinalizeMemRefToLLVMConversionPatterns
    %mlir::populateFinalizeMemRefToLLVMConversionPatterns))

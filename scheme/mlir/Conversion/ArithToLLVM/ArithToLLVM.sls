#!r6rs
;; Mirrors mlir/Conversion/ArithToLLVM/ArithToLLVM.h
(library (mlir Conversion ArithToLLVM ArithToLLVM)
  (export mlir::arith::populateArithToLLVMConversionPatterns)
  (import (rnrs) (mlir Conversion ArithToLLVM ArithToLLVM ffi))
  (define mlir::arith::populateArithToLLVMConversionPatterns
    %mlir::arith::populateArithToLLVMConversionPatterns))

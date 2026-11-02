#!r6rs
;; Mirrors mlir/Conversion/ArithToLLVM/ArithToLLVM.h
(library (mlir Conversion ArithToLLVM ArithToLLVM ffi)
  (export %mlir::arith::populateArithToLLVMConversionPatterns)
  (import (chezscheme))
  (define %mlir::arith::populateArithToLLVMConversionPatterns
    (foreign-procedure "mlir::arith::populateArithToLLVMConversionPatterns" (uptr uptr) void)))

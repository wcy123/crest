#!r6rs
;; Mirrors mlir/Conversion/FuncToLLVM/ConvertFuncToLLVM.h
(library (mlir Conversion FuncToLLVM ConvertFuncToLLVM)
  (export mlir::populateFuncToLLVMConversionPatterns)
  (import (rnrs) (mlir Conversion FuncToLLVM ConvertFuncToLLVM ffi))
  (define mlir::populateFuncToLLVMConversionPatterns
    %mlir::populateFuncToLLVMConversionPatterns))

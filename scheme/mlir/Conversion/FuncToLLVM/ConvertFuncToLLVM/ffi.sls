#!r6rs
;; Mirrors mlir/Conversion/FuncToLLVM/ConvertFuncToLLVM.h
(library (mlir Conversion FuncToLLVM ConvertFuncToLLVM ffi)
  (export %mlir::populateFuncToLLVMConversionPatterns)
  (import (chezscheme)
          (crest support foreign))
  (define %mlir::populateFuncToLLVMConversionPatterns
    (crest-foreign-procedure "mlir::populateFuncToLLVMConversionPatterns" (uptr uptr) void)))

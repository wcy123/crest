#!r6rs
;; Mirrors mlir/Conversion/LLVMCommon/TypeConverter.h
(library (mlir Conversion LLVMCommon TypeConverter ffi)
  (export %mlir::LLVMTypeConverter::LLVMTypeConverter)
  (import (chezscheme))
  (define %mlir::LLVMTypeConverter::LLVMTypeConverter
    (foreign-procedure "mlir::LLVMTypeConverter::LLVMTypeConverter" (uptr) uptr)))

#!r6rs
;; Mirrors mlir/Conversion/LLVMCommon/TypeConverter.h
(library (mlir Conversion LLVMCommon TypeConverter ffi)
  (export %mlir::LLVMTypeConverter::LLVMTypeConverter)
  (import (chezscheme)
          (mlir support foreign))
  (define %mlir::LLVMTypeConverter::LLVMTypeConverter
    (crest-foreign-procedure "mlir::LLVMTypeConverter::LLVMTypeConverter" (uptr) uptr)))

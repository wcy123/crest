#!r6rs
;; Mirrors mlir/Conversion/LLVMCommon/TypeConverter.h
(library (mlir Conversion LLVMCommon TypeConverter)
  (export with-LLVMTypeConverter)
  (import (rnrs)
          (mlir Conversion LLVMCommon TypeConverter ffi)
          (only (crest support CrestObject) with-CrestObject)
          (only (mlir IR MLIRContext) current-MLIRContext))

  ;; Not exported: it answers a heap box that only with-LLVMTypeConverter frees (a raw call leaks it).
  (define mlir::LLVMTypeConverter::LLVMTypeConverter
    (case-lambda
     [()      (%mlir::LLVMTypeConverter::LLVMTypeConverter (current-MLIRContext))]
     [(ctx)   (%mlir::LLVMTypeConverter::LLVMTypeConverter ctx)]))

  ;; RAII: create an LLVMTypeConverter, execute body, free it.
  (define-syntax with-LLVMTypeConverter
    (syntax-rules ()
      [(_ var () body ...)
       (with-CrestObject var (mlir::LLVMTypeConverter::LLVMTypeConverter) body ...)]
      [(_ var (ctx) body ...)
       (with-CrestObject var (mlir::LLVMTypeConverter::LLVMTypeConverter ctx) body ...)])))

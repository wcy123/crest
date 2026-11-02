#!r6rs
;; Mirrors mlir/Conversion/LLVMCommon/TypeConverter.h
(library (mlir Conversion LLVMCommon TypeConverter)
  (export mlir::LLVMTypeConverter::LLVMTypeConverter
          with-LLVMTypeConverter)
  (import (rnrs)
          (mlir Conversion LLVMCommon TypeConverter ffi)
          (only (mlir support array-ref) with-CrestObject)
          (only (mlir IR MLIRContext) current-MLIRContext))

  (define mlir::LLVMTypeConverter::LLVMTypeConverter
    (case-lambda
     [()      (%mlir::LLVMTypeConverter::LLVMTypeConverter (current-MLIRContext))]
     [(ctx)   (%mlir::LLVMTypeConverter::LLVMTypeConverter ctx)]))

  ;; RAII: create an LLVMTypeConverter, execute body, free it.
  (define-syntax with-LLVMTypeConverter
    (syntax-rules ()
      [(_ (var) body ...)
       (with-CrestObject (var (mlir::LLVMTypeConverter::LLVMTypeConverter)) body ...)]
      [(_ (var ctx) body ...)
       (with-CrestObject (var (mlir::LLVMTypeConverter::LLVMTypeConverter ctx)) body ...)])))

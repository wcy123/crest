#!r6rs
;; Mirrors mlir/Conversion/ControlFlowToLLVM/ControlFlowToLLVM.h
(library (mlir Conversion ControlFlowToLLVM ControlFlowToLLVM)
  (export mlir::cf::populateControlFlowToLLVMConversionPatterns
          mlir::cf::populateAssertToLLVMConversionPattern)
  (import (rnrs) (mlir Conversion ControlFlowToLLVM ControlFlowToLLVM ffi))
  (define mlir::cf::populateControlFlowToLLVMConversionPatterns
    %mlir::cf::populateControlFlowToLLVMConversionPatterns)
  (define mlir::cf::populateAssertToLLVMConversionPattern
    %mlir::cf::populateAssertToLLVMConversionPattern))

#!r6rs
;; Mirrors mlir/Conversion/ControlFlowToLLVM/ControlFlowToLLVM.h
(library (mlir Conversion ControlFlowToLLVM ControlFlowToLLVM ffi)
  (export %mlir::cf::populateControlFlowToLLVMConversionPatterns
          %mlir::cf::populateAssertToLLVMConversionPattern)
  (import (chezscheme)
          (crest support foreign))
  (define %mlir::cf::populateControlFlowToLLVMConversionPatterns
    (crest-foreign-procedure "mlir::cf::populateControlFlowToLLVMConversionPatterns" (uptr uptr) void))
  (define %mlir::cf::populateAssertToLLVMConversionPattern
    (crest-foreign-procedure "mlir::cf::populateAssertToLLVMConversionPattern" (uptr uptr) void)))

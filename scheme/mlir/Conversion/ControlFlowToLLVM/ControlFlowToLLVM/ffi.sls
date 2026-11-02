#!r6rs
;; Mirrors mlir/Conversion/ControlFlowToLLVM/ControlFlowToLLVM.h
(library (mlir Conversion ControlFlowToLLVM ControlFlowToLLVM ffi)
  (export %mlir::cf::populateControlFlowToLLVMConversionPatterns)
  (import (chezscheme))
  (define %mlir::cf::populateControlFlowToLLVMConversionPatterns
    (foreign-procedure "mlir::cf::populateControlFlowToLLVMConversionPatterns" (uptr uptr) void)))

#!r6rs
;; Mirrors mlir/Target/LLVMIR/Export.h
(library (mlir Target LLVMIR Export ffi)
  (export %mlir::translateModuleToLLVMIR)
  (import (chezscheme))
  (define %mlir::translateModuleToLLVMIR
    (foreign-procedure "mlir::translateModuleToLLVMIR" (uptr) string)))

#!r6rs
;; Mirrors mlir/Target/LLVMIR/Export.h
(library (mlir Target LLVMIR Export ffi)
  (export %mlir::translateModuleToLLVMIR
          %mlir::translateModuleToLLVMIR<int>)
  (import (chezscheme))
  (define %mlir::translateModuleToLLVMIR
    (foreign-procedure "mlir::translateModuleToLLVMIR" (uptr) string))
  (define %mlir::translateModuleToLLVMIR<int>
    (foreign-procedure "mlir::translateModuleToLLVMIR<int>" (uptr int) string)))

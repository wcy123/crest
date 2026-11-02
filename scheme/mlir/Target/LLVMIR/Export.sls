#!r6rs
;; Mirrors mlir/Target/LLVMIR/Export.h
(library (mlir Target LLVMIR Export)
  (export mlir::translateModuleToLLVMIR)
  (import (rnrs) (mlir Target LLVMIR Export ffi))
  (define mlir::translateModuleToLLVMIR %mlir::translateModuleToLLVMIR))

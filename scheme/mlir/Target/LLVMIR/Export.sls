#!r6rs
;; Mirrors mlir/Target/LLVMIR/Export.h
(library (mlir Target LLVMIR Export)
  (export mlir::translateModuleToLLVMIR)
  (import (rnrs)
          (mlir Target LLVMIR Export ffi))

  ;; (translateModuleToLLVMIR module) is the module translated to LLVM IR text.
  ;; (translateModuleToLLVMIR module opt-level) also sets the target triple and data layout of the
  ;; host and runs LLVM's optimizing pipeline at opt-level 0 to 3, as the C++ Toy tutorial does.
  ;; The text comes back as a Scheme string: nothing to copy or free.
  (define mlir::translateModuleToLLVMIR
    (case-lambda
     [(module)           (%mlir::translateModuleToLLVMIR module)]
     [(module opt-level) (%mlir::translateModuleToLLVMIR<int> module opt-level)])))

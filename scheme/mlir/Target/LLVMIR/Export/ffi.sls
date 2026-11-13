#!r6rs
;; Mirrors mlir/Target/LLVMIR/Export.h
(library (mlir Target LLVMIR Export ffi)
  (export %mlir::translateModuleToLLVMIR
          %mlir::translateModuleToLLVMIR<int>)
  (import (chezscheme)
          (crest support foreign))
  (define %mlir::translateModuleToLLVMIR
    (crest-foreign-procedure "mlir::translateModuleToLLVMIR" (uptr) string))
  (define %mlir::translateModuleToLLVMIR<int>
    (crest-foreign-procedure "mlir::translateModuleToLLVMIR<int>" (uptr int) string)))

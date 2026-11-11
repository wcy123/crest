#!r6rs
;; Mirrors mlir/Target/LLVMIR/Export.h
(library (mlir Target LLVMIR Export ffi)
  (export %mlir::translateModuleToLLVMIR
          %mlir::translateModuleToLLVMIR<int>)
  (import (chezscheme))
  ;; Both answer the address of a NUL-terminated UTF-8 text that C++ made with malloc. The caller copies
  ;; it and frees it (foreign-free): a `string` result would copy it and leave the buffer behind.
  (define %mlir::translateModuleToLLVMIR
    (foreign-procedure "mlir::translateModuleToLLVMIR" (uptr) uptr))
  (define %mlir::translateModuleToLLVMIR<int>
    (foreign-procedure "mlir::translateModuleToLLVMIR<int>" (uptr int) uptr)))

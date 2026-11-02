#!r6rs
;; Mirrors mlir/Dialect/LLVMIR/Transforms/Passes.h
(library (mlir Dialect LLVMIR Transforms Passes ffi)
  (export %mlir::LLVM::createDIScopeForLLVMFuncOpPass)
  (import (chezscheme))
  (define %mlir::LLVM::createDIScopeForLLVMFuncOpPass
    (foreign-procedure "mlir::LLVM::createDIScopeForLLVMFuncOpPass" () uptr)))

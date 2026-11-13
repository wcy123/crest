#!r6rs
;; Mirrors mlir/Dialect/LLVMIR/Transforms/Passes.h
(library (mlir Dialect LLVMIR Transforms Passes ffi)
  (export %mlir::LLVM::createDIScopeForLLVMFuncOpPass)
  (import (chezscheme)
          (crest support foreign))
  (define %mlir::LLVM::createDIScopeForLLVMFuncOpPass
    (crest-foreign-procedure "mlir::LLVM::createDIScopeForLLVMFuncOpPass" () uptr)))

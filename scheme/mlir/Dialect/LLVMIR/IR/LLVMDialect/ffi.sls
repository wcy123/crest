#!r6rs
;; Mirrors mlir/Dialect/LLVMIR/IR/LLVMDialect.h
(library (mlir Dialect LLVMIR IR LLVMDialect ffi)
  (export %mlir::LLVM::LLVMDialect
          %mlir::LLVM::registerInlinerInterface)
  (import (chezscheme))
  (define %mlir::LLVM::LLVMDialect
    (foreign-procedure "mlir::LLVM::LLVMDialect" (uptr) void))
  (define %mlir::LLVM::registerInlinerInterface
    (foreign-procedure "mlir::LLVM::registerInlinerInterface" (uptr) void)))

#!r6rs
;; Mirrors mlir/Dialect/LLVMIR/IR/LLVMDialect.h
(library (mlir Dialect LLVMIR IR LLVMDialect)
  (export mlir::LLVM::LLVMDialect
          mlir::LLVM::registerInlinerInterface)
  (import (rnrs) (mlir Dialect LLVMIR IR LLVMDialect ffi))
  (define mlir::LLVM::LLVMDialect         %mlir::LLVM::LLVMDialect)
  (define mlir::LLVM::registerInlinerInterface %mlir::LLVM::registerInlinerInterface))

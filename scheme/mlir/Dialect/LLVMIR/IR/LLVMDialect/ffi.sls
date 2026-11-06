#!r6rs
;; Mirrors mlir/Dialect/LLVMIR/IR/LLVMDialect.h
(library (mlir Dialect LLVMIR IR LLVMDialect ffi)
  (export %mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>
          %mlir::LLVM::registerInlinerInterface)
  (import (chezscheme))
  (define %mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>
    (foreign-procedure "mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>" (uptr) void))
  (define %mlir::LLVM::registerInlinerInterface
    (foreign-procedure "mlir::LLVM::registerInlinerInterface" (uptr) void)))

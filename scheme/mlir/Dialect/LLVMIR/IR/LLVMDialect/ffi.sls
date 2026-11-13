#!r6rs
;; Mirrors mlir/Dialect/LLVMIR/IR/LLVMDialect.h
(library (mlir Dialect LLVMIR IR LLVMDialect ffi)
  (export %mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>
          %mlir::LLVM::registerInlinerInterface)
  (import (chezscheme)
          (crest support foreign))
  (define %mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>
    (crest-foreign-procedure "mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect>" (uptr) void))
  (define %mlir::LLVM::registerInlinerInterface
    (crest-foreign-procedure "mlir::LLVM::registerInlinerInterface" (uptr) void)))

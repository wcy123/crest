#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Dialect/LLVMIR/LLVMDialect.h
(library (mlir Dialect LLVMIR IR LLVMOps ffi)
  (export %mlir::LLVM::LLVMFunctionType::get
          %mlir::LLVM::LLVMPointerType::get
          %mlir::LLVM::LLVMArrayType::get
          %mlir::LLVM::LLVMFuncOp::create
          %mlir::LLVM::GlobalOp::create
          %mlir::LLVM::GlobalOp::getType
          %mlir::LLVM::AddressOfOp::create
          %mlir::LLVM::GEPOp::create
          %mlir::LLVM::ConstantOp::create<i64>
          %mlir::LLVM::CallOp::create
          %mlir::ModuleOp::lookupSymbol
          %mlir::FlatSymbolRefAttr::get)
  (import (chezscheme)
          (mlir support foreign) (mlir support BuilderBinding))

  (define %mlir::LLVM::LLVMFunctionType::get
    (crest-foreign-procedure "mlir::LLVM::LLVMFunctionType::get" (uptr uptr uptr int) uptr))

  (define %mlir::LLVM::LLVMPointerType::get
    (crest-foreign-procedure "mlir::LLVM::LLVMPointerType::get" (uptr) uptr))

  (define %mlir::LLVM::LLVMArrayType::get
    (crest-foreign-procedure "mlir::LLVM::LLVMArrayType::get" (uptr uptr) uptr))

  (define-builder-binding %mlir::LLVM::LLVMFuncOp::create
    "mlir::LLVM::LLVMFuncOp::create" (uptr uptr string uptr) uptr)

  (define-builder-binding %mlir::LLVM::GlobalOp::create
    "mlir::LLVM::GlobalOp::create" (uptr uptr uptr int int string uptr) uptr)

  (define %mlir::LLVM::GlobalOp::getType
    (crest-foreign-procedure "mlir::LLVM::GlobalOp::getType" (uptr) uptr))

  (define-builder-binding %mlir::LLVM::AddressOfOp::create
    "mlir::LLVM::AddressOfOp::create" (uptr uptr uptr) uptr)

  (define-builder-binding %mlir::LLVM::GEPOp::create
    "mlir::LLVM::GEPOp::create" (uptr uptr uptr uptr uptr uptr uptr) uptr)

  (define-builder-binding %mlir::LLVM::ConstantOp::create<i64>
    "mlir::LLVM::ConstantOp::create<i64>" (uptr uptr integer-64) uptr)

  (define-builder-binding %mlir::LLVM::CallOp::create
    "mlir::LLVM::CallOp::create" (uptr uptr uptr uptr scheme-object) uptr)

  (define %mlir::ModuleOp::lookupSymbol
    (crest-foreign-procedure "mlir::ModuleOp::lookupSymbol" (uptr string) uptr))

  (define %mlir::FlatSymbolRefAttr::get
    (crest-foreign-procedure "mlir::FlatSymbolRefAttr::get" (uptr string) uptr))

  ) ;; end library (mlir Dialect LLVMIR IR LLVMOps ffi)

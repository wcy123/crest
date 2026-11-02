#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Dialect/LLVMIR/LLVMDialect.h
(library (mlir Dialect LLVMIR IR LLVMOps)
  (export mlir::LLVM::LLVMFunctionType::get
          mlir::LLVM::LLVMPointerType::get
          mlir::LLVM::LLVMArrayType::get
          mlir::LLVM::LLVMFuncOp::create
          mlir::LLVM::GlobalOp::create
          mlir::LLVM::GlobalOp::getType
          mlir::LLVM::AddressOfOp::create
          mlir::LLVM::GEPOp::create
          mlir::LLVM::ConstantOp::create<i64>
          mlir::LLVM::CallOp::create
          mlir::ModuleOp::lookupSymbol
          mlir::FlatSymbolRefAttr::get)
  (import (rnrs)
          (mlir Dialect LLVMIR IR LLVMOps ffi))

  (define mlir::LLVM::LLVMFunctionType::get   %mlir::LLVM::LLVMFunctionType::get)
  (define mlir::LLVM::LLVMPointerType::get    %mlir::LLVM::LLVMPointerType::get)
  (define mlir::LLVM::LLVMArrayType::get      %mlir::LLVM::LLVMArrayType::get)
  (define mlir::LLVM::LLVMFuncOp::create      %mlir::LLVM::LLVMFuncOp::create)
  (define mlir::LLVM::GlobalOp::create        %mlir::LLVM::GlobalOp::create)
  (define mlir::LLVM::GlobalOp::getType       %mlir::LLVM::GlobalOp::getType)
  (define mlir::LLVM::AddressOfOp::create     %mlir::LLVM::AddressOfOp::create)
  (define mlir::LLVM::GEPOp::create           %mlir::LLVM::GEPOp::create)
  (define mlir::LLVM::ConstantOp::create<i64> %mlir::LLVM::ConstantOp::create<i64>)
  (define mlir::LLVM::CallOp::create          %mlir::LLVM::CallOp::create)
  (define mlir::ModuleOp::lookupSymbol        %mlir::ModuleOp::lookupSymbol)
  (define mlir::FlatSymbolRefAttr::get        %mlir::FlatSymbolRefAttr::get)

  ) ;; end library (mlir Dialect LLVMIR IR LLVMOps)

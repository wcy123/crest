#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Dialect MemRef IR MemRef) — Public API for mlir/Dialect/MemRef/IR/MemRef.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Dialect MemRef IR MemRef)
  (export mlir::MemRefType::get
          mlir::memref::AllocOp::create
          mlir::memref::DeallocOp::create
          mlir::DialectRegistry::insert<mlir::memref::MemRefDialect>
          mlir::memref::LoadOp::create)
  (import (rnrs)
          (mlir Dialect MemRef IR MemRef ffi))

  (define mlir::MemRefType::get          %mlir::MemRefType::get)
  (define mlir::memref::AllocOp::create  %mlir::memref::AllocOp::create)
  (define mlir::memref::DeallocOp::create %mlir::memref::DeallocOp::create)
  (define mlir::DialectRegistry::insert<mlir::memref::MemRefDialect>    %mlir::DialectRegistry::insert<mlir::memref::MemRefDialect>)
  (define mlir::memref::LoadOp::create   %mlir::memref::LoadOp::create)

  ) ;; end library (mlir Dialect MemRef IR MemRef)

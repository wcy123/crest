#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Dialect/MemRef/IR/MemRef.h
(library (mlir Dialect MemRef IR MemRef ffi)
  (export %mlir::MemRefType::get
          %mlir::memref::AllocOp::create
          %mlir::memref::DeallocOp::create
          %mlir::memref::MemRefDialect)
  (import (chezscheme))

  (define %mlir::MemRefType::get
    (foreign-procedure "mlir::MemRefType::get" (uptr) uptr))

  (define %mlir::memref::AllocOp::create
    (foreign-procedure "mlir::memref::AllocOp::create" (uptr uptr uptr) uptr))

  (define %mlir::memref::DeallocOp::create
    (foreign-procedure "mlir::memref::DeallocOp::create" (uptr uptr uptr) uptr))

  (define %mlir::memref::MemRefDialect
    (foreign-procedure "mlir::memref::MemRefDialect" (uptr) void))

  ) ;; end library (mlir Dialect MemRef IR MemRef ffi)

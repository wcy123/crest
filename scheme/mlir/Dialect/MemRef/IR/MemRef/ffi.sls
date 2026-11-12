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
          %mlir::DialectRegistry::insert<mlir::memref::MemRefDialect>
          %mlir::memref::LoadOp::create)
  (import (chezscheme)
          (mlir support foreign) (mlir support BuilderBinding))

  (define %mlir::MemRefType::get
    (crest-foreign-procedure "mlir::MemRefType::get" (uptr) uptr))

  (define-builder-binding %mlir::memref::AllocOp::create
    "mlir::memref::AllocOp::create" (uptr uptr uptr) uptr)

  (define-builder-binding %mlir::memref::DeallocOp::create
    "mlir::memref::DeallocOp::create" (uptr uptr uptr) uptr)

  (define %mlir::DialectRegistry::insert<mlir::memref::MemRefDialect>
    (crest-foreign-procedure "mlir::DialectRegistry::insert<mlir::memref::MemRefDialect>" (uptr) void))

  (define-builder-binding %mlir::memref::LoadOp::create
    "mlir::memref::LoadOp::create" (uptr uptr uptr scheme-object) uptr)

  ) ;; end library (mlir Dialect MemRef IR MemRef ffi)

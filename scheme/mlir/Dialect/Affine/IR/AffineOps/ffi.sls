#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Dialect/Affine/IR/AffineOps.h
(library (mlir Dialect Affine IR AffineOps ffi)
  (export %mlir::affine::buildAffineLoopNest
          %mlir::affine::AffineLoadOp::create
          %mlir::affine::AffineStoreOp::create
          %mlir::affine::AffineDialect)
  (import (chezscheme))

  (define %mlir::affine::buildAffineLoopNest
    (foreign-procedure "mlir::affine::buildAffineLoopNest"
                       (uptr uptr scheme-object scheme-object) void))

  (define %mlir::affine::AffineLoadOp::create
    (foreign-procedure "mlir::affine::AffineLoadOp::create"
                       (uptr uptr uptr scheme-object) uptr))

  (define %mlir::affine::AffineStoreOp::create
    (foreign-procedure "mlir::affine::AffineStoreOp::create"
                       (uptr uptr uptr uptr scheme-object) void))

  (define %mlir::affine::AffineDialect
    (foreign-procedure "mlir::affine::AffineDialect" (uptr) void))

  ) ;; end library (mlir Dialect Affine IR AffineOps ffi)

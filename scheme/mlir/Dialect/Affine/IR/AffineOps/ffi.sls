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
          %mlir::affine::AffineLoadOp::create<AffineMap>
          %mlir::affine::AffineStoreOp::create<AffineMap>
          %mlir::DialectRegistry::insert<mlir::affine::AffineDialect>)
  (import (chezscheme)
          (mlir support foreign) (mlir support BuilderBinding))

  (define-builder-binding %mlir::affine::buildAffineLoopNest
    "mlir::affine::buildAffineLoopNest"
    (uptr uptr scheme-object scheme-object scheme-object uptr) void)

  (define-builder-binding %mlir::affine::AffineLoadOp::create
    "mlir::affine::AffineLoadOp::create" (uptr uptr uptr scheme-object) uptr)

  (define-builder-binding %mlir::affine::AffineStoreOp::create
    "mlir::affine::AffineStoreOp::create" (uptr uptr uptr uptr scheme-object) void)

  (define-builder-binding %mlir::affine::AffineLoadOp::create<AffineMap>
    "mlir::affine::AffineLoadOp::create<AffineMap>"
    (uptr uptr uptr uptr scheme-object) uptr)

  (define-builder-binding %mlir::affine::AffineStoreOp::create<AffineMap>
    "mlir::affine::AffineStoreOp::create<AffineMap>"
    (uptr uptr uptr uptr uptr scheme-object) void)

  (define %mlir::DialectRegistry::insert<mlir::affine::AffineDialect>
    (crest-foreign-procedure "mlir::DialectRegistry::insert<mlir::affine::AffineDialect>" (uptr) void))

  ) ;; end library (mlir Dialect Affine IR AffineOps ffi)

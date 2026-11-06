#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Dialect Affine IR AffineOps) — Public API for
;; mlir/Dialect/Affine/IR/AffineOps.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Dialect Affine IR AffineOps)
  (export mlir::affine::buildAffineLoopNest
          mlir::affine::AffineLoadOp::create
          mlir::affine::AffineStoreOp::create
          mlir::affine::AffineLoadOp::create<AffineMap>
          mlir::affine::AffineStoreOp::create<AffineMap>
          mlir::DialectRegistry::insert<mlir::affine::AffineDialect>)
  (import (rnrs)
          (mlir Dialect Affine IR AffineOps ffi))

  (define mlir::affine::buildAffineLoopNest
    %mlir::affine::buildAffineLoopNest)

  (define mlir::affine::AffineLoadOp::create
    %mlir::affine::AffineLoadOp::create)

  (define mlir::affine::AffineStoreOp::create
    %mlir::affine::AffineStoreOp::create)

  (define mlir::affine::AffineLoadOp::create<AffineMap>
    %mlir::affine::AffineLoadOp::create<AffineMap>)

  (define mlir::affine::AffineStoreOp::create<AffineMap>
    %mlir::affine::AffineStoreOp::create<AffineMap>)

  (define mlir::DialectRegistry::insert<mlir::affine::AffineDialect>
    %mlir::DialectRegistry::insert<mlir::affine::AffineDialect>)

  ) ;; end library (mlir Dialect Affine IR AffineOps)

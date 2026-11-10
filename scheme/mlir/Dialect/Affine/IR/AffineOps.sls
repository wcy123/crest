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
          (crest callback)
          (mlir Dialect Affine IR AffineOps ffi))

  ;; @brief buildAffineLoopNest: build a nest of loops with constant bounds and steps, and call
  ;;        BODY inside the innermost one.
  ;; @param builder  a builder shell
  ;; @param loc      Location uptr
  ;; @param lbs ubs steps  lists of integers, one per loop
  ;; @param body     (nested-builder loc ivs): the builder shell for the body (valid during the call)
  ;;                 and the list of the induction variables. C++ makes it into a C function for this
  ;;                 call and releases it when the call returns.
  (define (mlir::affine::buildAffineLoopNest builder loc lbs ubs steps body)
    (%mlir::affine::buildAffineLoopNest
     builder loc lbs ubs steps
     (lambda (nested-builder nested-loc ivs count)
       (body nested-builder nested-loc (crest-callback-pointer-list ivs count)))))

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

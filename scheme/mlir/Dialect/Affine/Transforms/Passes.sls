#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Dialect Affine Transforms Passes) — Public API for
;; mlir/Dialect/Affine/Transforms/Passes.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Dialect Affine Transforms Passes)
  (export mlir::affine::createLoopFusionPass
          mlir::affine::createAffineScalarReplacementPass)
  (import (rnrs)
          (mlir Dialect Affine Transforms Passes ffi))

  (define mlir::affine::createLoopFusionPass
    %mlir::affine::createLoopFusionPass)

  (define mlir::affine::createAffineScalarReplacementPass
    %mlir::affine::createAffineScalarReplacementPass)

  ) ;; end library (mlir Dialect Affine Transforms Passes)

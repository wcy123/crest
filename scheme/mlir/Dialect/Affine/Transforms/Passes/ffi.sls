#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Dialect/Affine/Transforms/Passes.h
(library (mlir Dialect Affine Transforms Passes ffi)
  (export %mlir::affine::createLoopFusionPass
          %mlir::affine::createAffineScalarReplacementPass)
  (import (chezscheme))

  (define %mlir::affine::createLoopFusionPass
    (foreign-procedure "mlir::affine::createLoopFusionPass" () uptr))

  (define %mlir::affine::createAffineScalarReplacementPass
    (foreign-procedure "mlir::affine::createAffineScalarReplacementPass" () uptr))

  ) ;; end library (mlir Dialect Affine Transforms Passes ffi)

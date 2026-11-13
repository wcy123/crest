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
  (import (chezscheme)
          (crest support foreign))

  (define %mlir::affine::createLoopFusionPass
    (crest-foreign-procedure "mlir::affine::createLoopFusionPass" () uptr))

  (define %mlir::affine::createAffineScalarReplacementPass
    (crest-foreign-procedure "mlir::affine::createAffineScalarReplacementPass" () uptr))

  ) ;; end library (mlir Dialect Affine Transforms Passes ffi)

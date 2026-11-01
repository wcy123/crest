#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Transforms Passes) — Public API for mlir/Transforms/Passes.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Transforms Passes)
  (export mlir::createCanonicalizerPass
          mlir::createCSEPass)
  (import (rnrs)
          (mlir Transforms Passes ffi))

  (define mlir::createCanonicalizerPass %mlir::createCanonicalizerPass)

  (define mlir::createCSEPass %mlir::createCSEPass)

  ) ;; end library (mlir Transforms Passes)

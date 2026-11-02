#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Transforms/Passes.h
(library (mlir Transforms Passes ffi)
  (export %mlir::createCanonicalizerPass
          %mlir::createCSEPass)
  (import (chezscheme))

  (define %mlir::createCanonicalizerPass
    (foreign-procedure "mlir::createCanonicalizerPass" () uptr))

  (define %mlir::createCSEPass
    (foreign-procedure "mlir::createCSEPass" () uptr))

  ) ;; end library (mlir Transforms Passes ffi)

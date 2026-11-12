#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Conversion/ReconcileUnrealizedCasts/ReconcileUnrealizedCasts.h
(library (mlir Conversion ReconcileUnrealizedCasts ReconcileUnrealizedCasts ffi)
  (export %mlir::createReconcileUnrealizedCastsPass)
  (import (chezscheme)
          (mlir support foreign))

  (define %mlir::createReconcileUnrealizedCastsPass
    (crest-foreign-procedure "mlir::createReconcileUnrealizedCastsPass" () uptr))

  ) ;; end library (mlir Conversion ReconcileUnrealizedCasts ReconcileUnrealizedCasts ffi)

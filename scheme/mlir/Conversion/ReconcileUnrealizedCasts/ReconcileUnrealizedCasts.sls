#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Conversion ReconcileUnrealizedCasts ReconcileUnrealizedCasts)
;; Mirrors mlir/Conversion/ReconcileUnrealizedCasts/ReconcileUnrealizedCasts.h
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Conversion ReconcileUnrealizedCasts ReconcileUnrealizedCasts)
  (export mlir::createReconcileUnrealizedCastsPass)
  (import (rnrs)
          (mlir Conversion ReconcileUnrealizedCasts ReconcileUnrealizedCasts ffi))

  (define mlir::createReconcileUnrealizedCastsPass
    %mlir::createReconcileUnrealizedCastsPass)

  ) ;; end library (mlir Conversion ReconcileUnrealizedCasts ReconcileUnrealizedCasts)

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects shape) — backward-compatibility shim.
;;
;; Canonical library is (mlir dialect shape). This shim re-exports the old
;; dot-namespaced names so existing code continues to work.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialects shape)
  (export
    mlir-shape.shape-type
    mlir-shape.size-type
    mlir-shape.witness-type)
  (import (rnrs) (mlir dialect shape))

  (define mlir-shape.shape-type   shape-type-get)
  (define mlir-shape.size-type    size-type-get)
  (define mlir-shape.witness-type witness-type-get)

) ;; end library (mlir dialects shape)

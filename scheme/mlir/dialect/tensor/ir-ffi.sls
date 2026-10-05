#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects tensor ffi) — raw C bindings for tensor dialect type ops.
;;
;; % prefix = raw C binding. Prefer (mlir dialect tensor ir) for normal use.
;;
;; Mirrors mlir/Dialect/Tensor/IR/Tensor.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialect tensor ir-ffi)
  (export %ranked-tensor-type-with-encoding
          %tensor-cast-are-cast-compatible
          %tensor-cast-create)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %ranked-tensor-type-with-encoding
    (foreign-procedure "crest::RankedTensorType::cloneWithEncoding" (uptr uptr) uptr))

  ;; @brief tensor::CastOp::areCastCompatible — test whether a tensor.cast
  ;;        between two types is valid.
  ;; @param from-type-uptr Type opaque uptr
  ;; @param to-type-uptr   Type opaque uptr
  ;; @return               1 if compatible, 0 otherwise
  ;; @note  Defined in lib/Bindings/Dialect/Tensor/Tensor.cpp
  (define %tensor-cast-are-cast-compatible
    (foreign-procedure "mlir_dialect_tensor_cast_are_cast_compatible"
                       (uptr uptr) int))

  ;; @brief tensor::CastOp::create — insert a tensor.cast op.
  ;; @param builder-uptr      OpBuilder* uptr
  ;; @param loc-uptr          Location opaque uptr
  ;; @param result-type-uptr  Type opaque uptr
  ;; @param input-value-uptr  Value opaque uptr
  ;; @return                  Value opaque uptr of the cast result, or 0
  ;; @note  Defined in lib/Bindings/Dialect/Tensor/Tensor.cpp
  (define %tensor-cast-create
    (foreign-procedure "mlir_dialect_tensor_cast_create"
                       (uptr uptr uptr uptr) uptr))

) ;; end library (mlir dialects tensor ffi)

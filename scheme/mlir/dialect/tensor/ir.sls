#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects tensor) — Generic tensor type operations.
;;
;; Mirrors mlir/Dialect/Tensor/IR/Tensor.h for type-level operations.
;; These are dialect-agnostic: they operate on RankedTensorType and
;; accept any MLIR attribute as an encoding.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialect tensor ir)
  (export crest::RankedTensorType::cloneWithEncoding
          mlir::tensor::CastOp::areCastCompatible
          mlir::tensor::CastOp::create)

  (import (rnrs) (mlir dialect tensor ir-ffi))

  (define crest::RankedTensorType::cloneWithEncoding
    %ranked-tensor-type-with-encoding)

  ;; @brief tensor::CastOp::areCastCompatible — test whether a tensor.cast
  ;;        between two types is valid.
  ;; @param from-type-uptr Type opaque uptr
  ;; @param to-type-uptr   Type opaque uptr
  ;; @return               1 if compatible, 0 otherwise
  (define mlir::tensor::CastOp::areCastCompatible
    %tensor-cast-are-cast-compatible)

  ;; @brief tensor::CastOp::create — insert a tensor.cast op and return its
  ;;        result value.
  ;; @param builder-uptr     OpBuilder* uptr
  ;; @param loc-uptr         Location opaque uptr
  ;; @param result-type-uptr Type opaque uptr
  ;; @param input-value-uptr Value opaque uptr
  ;; @return                 Value opaque uptr of the cast result, or 0
  (define mlir::tensor::CastOp::create
    %tensor-cast-create)

) ;; end library (mlir dialects tensor)

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
;; CREST-specific tensor utilities:
;; - crest::RankedTensorType::cloneWithEncoding — from mlir/IR/BuiltinTypes.h
;; - mlir::tensor::CastOp::areCastCompatible   — from mlir/Interfaces/CastInterfaces.h
;; - mlir::tensor::CastOp::create               — from mlir/Dialect/Tensor/IR/Tensor.h
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialect tensor ir ffi)
  (export %crest::RankedTensorType::cloneWithEncoding
          %mlir::tensor::CastOp::areCastCompatible
          %mlir::tensor::CastOp::create)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief crest::RankedTensorType::cloneWithEncoding — clone a RankedTensorType
  ;;        with a new encoding attribute.
  ;; @param tensor-type-uptr  RankedTensorType opaque uptr
  ;; @param encoding-uptr     Attribute opaque uptr — new encoding (may be null)
  ;; @return                  RankedTensorType opaque uptr with the new encoding
  ;; @see   mlir/IR/BuiltinTypes.h
  ;; @note  Defined in lib/Bindings/Dialect/Tensor/Tensor.cpp
  (define %crest::RankedTensorType::cloneWithEncoding
    (foreign-procedure "crest::RankedTensorType::cloneWithEncoding" (uptr uptr) uptr))

  ;; @brief tensor::CastOp::areCastCompatible — test whether a tensor.cast
  ;;        between two types is valid.
  ;; @param from-type-uptr Type opaque uptr
  ;; @param to-type-uptr   Type opaque uptr
  ;; @return               1 if compatible, 0 otherwise
  ;; @note  Defined in lib/Bindings/Dialect/Tensor/Tensor.cpp
  (define %mlir::tensor::CastOp::areCastCompatible
    (foreign-procedure "mlir::tensor::CastOp::areCastCompatible"
                       (uptr uptr) int))

  ;; @brief tensor::CastOp::create — insert a tensor.cast op.
  ;; @param builder-uptr      OpBuilder* uptr
  ;; @param loc-uptr          Location opaque uptr
  ;; @param result-type-uptr  Type opaque uptr
  ;; @param input-value-uptr  Value opaque uptr
  ;; @return                  Value opaque uptr of the cast result, or 0
  ;; @note  Defined in lib/Bindings/Dialect/Tensor/Tensor.cpp
  (define %mlir::tensor::CastOp::create
    (foreign-procedure "mlir::tensor::CastOp::create"
                       (uptr uptr uptr uptr) uptr))

) ;; end library (mlir dialects tensor ffi)

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialect shape) — Shape dialect type factories.
;;
;; Mirrors mlir/Dialect/Shape/IR/Shape.h.
;; C function names follow the pattern: mlir_dialect_shape_<type>_get.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialect shape)
  (export
    shape-type-get
    size-type-get
    witness-type-get)
  (import (chezscheme))

  ;; mlir::shape::ShapeType::get(ctx) → !shape.shape
  (define shape-type-get
    (foreign-procedure "mlir_dialect_shape_shape_type_get" (uptr) uptr))

  ;; mlir::shape::SizeType::get(ctx) → !shape.size
  (define size-type-get
    (foreign-procedure "mlir_dialect_shape_size_type_get" (uptr) uptr))

  ;; mlir::shape::WitnessType::get(ctx) → !shape.witness
  (define witness-type-get
    (foreign-procedure "mlir_dialect_shape_witness_type_get" (uptr) uptr))

) ;; end library (mlir dialect shape)

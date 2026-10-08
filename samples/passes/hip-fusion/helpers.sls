#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (passes hip-fusion helpers) — shared attr-setter helpers and FFI bindings
;; used by every per-op pattern sub-library.
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion helpers)
  (export
    set-qdq-scale-zp-attrs!
    set-qdq-in-out-attrs!
    mlir-operation-set-dense-i32-array!
    mlir-operation-set-dense-i64-array!
    mlir-operation-set-i64-array-attr!
    op-get-f32-attr)              ; (op name) → flonum or +nan.0 if absent

  (import (except (rnrs) =)
          (only (mlir IR Operation)
                mlir::Operation::getAttr
                mlir::Operation::setAttr!)
          (only (mlir IR BuiltinAttributes)
                mlir::FloatAttr::get<f32>
                mlir::FloatAttr::getValueAsDouble.f32
                mlir::IntegerAttr::get<i64>
                mlir::DenseI32ArrayAttr::get
                mlir::DenseI64ArrayAttr::get
                mlir::IntegerAttr::get<i64>))

  (define (set-qdq-scale-zp-attrs! new-op
                                   lhs-scale lhs-zp
                                   rhs-scale rhs-zp
                                   out-scale out-zp)
    (mlir::Operation::setAttr! new-op "lhs_scale"    (mlir::FloatAttr::get<f32> lhs-scale))
    (mlir::Operation::setAttr! new-op "rhs_scale"    (mlir::FloatAttr::get<f32> rhs-scale))
    (mlir::Operation::setAttr! new-op "output_scale" (mlir::FloatAttr::get<f32> out-scale))
    (mlir::Operation::setAttr! new-op "lhs_zp"       (mlir::IntegerAttr::get<i64> lhs-zp))
    (mlir::Operation::setAttr! new-op "rhs_zp"       (mlir::IntegerAttr::get<i64> rhs-zp))
    (mlir::Operation::setAttr! new-op "output_zp"    (mlir::IntegerAttr::get<i64> out-zp)))

  (define (set-qdq-in-out-attrs! new-op in-scale in-zp out-scale out-zp)
    (mlir::Operation::setAttr! new-op "input_scale"  (mlir::FloatAttr::get<f32> in-scale))
    (mlir::Operation::setAttr! new-op "input_zp"     (mlir::IntegerAttr::get<i64> in-zp))
    (mlir::Operation::setAttr! new-op "output_scale" (mlir::FloatAttr::get<f32> out-scale))
    (mlir::Operation::setAttr! new-op "output_zp"    (mlir::IntegerAttr::get<i64> out-zp)))

  (define (mlir-operation-set-dense-i32-array! op name vals)
    (mlir::Operation::setAttr! op name (mlir::DenseI32ArrayAttr::get vals)))

  (define (mlir-operation-set-dense-i64-array! op name vals)
    (mlir::Operation::setAttr! op name (mlir::DenseI64ArrayAttr::get vals)))

  ;; setI64ArrayAttr creates ArrayAttr<IntegerAttr> which differs from DenseI64ArrayAttr.
  ;; qconv.sls uses this for kernel_shape/strides/pads/dilations that hip ops expect
  ;; as ArrayAttr. Keep binding until hip op definitions are updated to DenseI64Array.
  (define (mlir-operation-set-i64-array-attr! op name vals)
    (mlir::Operation::setAttr! op name (mlir::DenseI64ArrayAttr::get vals)))

  (define (op-get-f32-attr op name)
    (let ([attr (mlir::Operation::getAttr op name)])
      (if (zero? attr) +nan.0 (mlir::FloatAttr::getValueAsDouble.f32 attr))))

  ) ;; end library (passes hip-fusion helpers)

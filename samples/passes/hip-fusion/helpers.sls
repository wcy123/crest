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
                crest::Operation::setF32Attr
                crest::Operation::setI64Attr
                crest::Operation::setDenseI32Array
                crest::Operation::setDenseI64Array
                crest::Operation::setI64ArrayAttr)
          (only (mlir IR BuiltinAttributes) mlir::FloatAttr::getValueAsDouble.f32))

  (define (set-qdq-scale-zp-attrs! new-op
                                   lhs-scale lhs-zp
                                   rhs-scale rhs-zp
                                   out-scale out-zp)
    (crest::Operation::setF32Attr new-op "lhs_scale"    lhs-scale)
    (crest::Operation::setF32Attr new-op "rhs_scale"    rhs-scale)
    (crest::Operation::setF32Attr new-op "output_scale" out-scale)
    (crest::Operation::setI64Attr new-op "lhs_zp"       lhs-zp)
    (crest::Operation::setI64Attr new-op "rhs_zp"       rhs-zp)
    (crest::Operation::setI64Attr new-op "output_zp"    out-zp))

  (define (set-qdq-in-out-attrs! new-op in-scale in-zp out-scale out-zp)
    (crest::Operation::setF32Attr new-op "input_scale"  in-scale)
    (crest::Operation::setI64Attr new-op "input_zp"     in-zp)
    (crest::Operation::setF32Attr new-op "output_scale" out-scale)
    (crest::Operation::setI64Attr new-op "output_zp"    out-zp))

  ;; Aliases for convenience — these are already in (mlir IR Operation)
  (define mlir-operation-set-dense-i32-array! crest::Operation::setDenseI32Array)
  (define mlir-operation-set-dense-i64-array! crest::Operation::setDenseI64Array)
  (define mlir-operation-set-i64-array-attr!  crest::Operation::setI64ArrayAttr)

  (define (op-get-f32-attr op name)
    (let ([attr (mlir::Operation::getAttr op name)])
      (if (zero? attr) +nan.0 (mlir::FloatAttr::getValueAsDouble.f32 attr))))

  ) ;; end library (passes hip-fusion helpers)

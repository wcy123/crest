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
          (only (chezscheme) foreign-procedure)
          (mlir core ir))

  (define (set-qdq-scale-zp-attrs! new-op
                                   lhs-scale lhs-zp
                                   rhs-scale rhs-zp
                                   out-scale out-zp)
    (mlir-operation-set-f32-attr! new-op "lhs_scale"    lhs-scale)
    (mlir-operation-set-f32-attr! new-op "rhs_scale"    rhs-scale)
    (mlir-operation-set-f32-attr! new-op "output_scale" out-scale)
    (mlir-operation-set-i64-attr! new-op "lhs_zp"       lhs-zp)
    (mlir-operation-set-i64-attr! new-op "rhs_zp"       rhs-zp)
    (mlir-operation-set-i64-attr! new-op "output_zp"    out-zp))

  (define (set-qdq-in-out-attrs! new-op in-scale in-zp out-scale out-zp)
    (mlir-operation-set-f32-attr! new-op "input_scale"  in-scale)
    (mlir-operation-set-i64-attr! new-op "input_zp"     in-zp)
    (mlir-operation-set-f32-attr! new-op "output_scale" out-scale)
    (mlir-operation-set-i64-attr! new-op "output_zp"    out-zp))

  (define mlir-operation-set-dense-i32-array!
    (foreign-procedure "mlir_operation_set_dense_i32_array" (uptr string scheme-object) void))

  (define mlir-operation-set-dense-i64-array!
    (foreign-procedure "mlir_operation_set_dense_i64_array" (uptr string scheme-object) void))

  ;; For ODS I64ArrayAttr (ArrayAttr of IntegerAttr) — different from DenseI64ArrayAttr
  (define mlir-operation-set-i64-array-attr!
    (foreign-procedure "mlir_operation_set_i64_array_attr" (uptr string scheme-object) void))

  ;; (op-get-f32-attr op name) — FloatAttr by name as flonum; +nan.0 if absent.
  ;; Expressed via mlir-attr-as :f32 so no separate FFI binding needed.
  (define %get-attr
    (foreign-procedure "mlir_operation_get_attribute" (uptr string) uptr))

  (define (op-get-f32-attr op name)
    (let ([attr (%get-attr op name)])
      (if (zero? attr) +nan.0 (mlir-attr-as attr :f32))))

) ;; end library (passes hip-fusion helpers)

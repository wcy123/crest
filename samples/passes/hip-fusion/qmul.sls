#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (passes hip-fusion qmul) — Pattern 2: QMul  (benefit 10)
;; dq × 2 → hip.mul → hip.quantize_linear  ⟹  hip.qmul
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion qmul)
  (export hip-qmul-fusion)

  (import (except (rnrs) =)
          (only (chezscheme) nan?)
          (rename (only (rnrs) =) (= num=))

          (only (mlir IR Value)
                mlir::Value::getDefiningOp
                mlir::Value::getType)
          (mlir Transforms DialectConversion)
          (passes hip-fusion fusion)
          (crest)
          (passes hip-fusion helpers)
          )

  (define-rewrite-pattern (hip-qmul-fusion op rewriter)
    :if-match
      %q   = hip.quantize_linear   (%ctx %prod %out_scale)
        :where (and (hip-splat-scale? %out_scale)
                    (hip-extractable-qdq-zeropoint? op))
      %prod = hip.mul              (%ctx %dq_lhs %dq_rhs %prod_init)
        :where (and (hip-value-single-use? %prod)
                    (hip-can-build-init? op %prod_init))
      %dq_lhs = hip.dequantize_linear (%ctx %lhs %lhs_scale)
        :where (and (hip-splat-scale? %lhs_scale)
                    (hip-extractable-qdq-zeropoint?
                     (mlir::Value::getDefiningOp %dq_lhs)))
      %dq_rhs = hip.dequantize_linear (%ctx %rhs %rhs_scale)
        :where (and (hip-splat-scale? %rhs_scale)
                    (hip-extractable-qdq-zeropoint?
                     (mlir::Value::getDefiningOp %dq_rhs)))
    :then-let
      ([!out-type  (mlir::Value::getType %q)]
       [%dq-lhs-op (mlir::Value::getDefiningOp %dq_lhs)]
       [%dq-rhs-op (mlir::Value::getDefiningOp %dq_rhs)]
       [lhs-scale  (hip-extract-splat-scale %lhs_scale)]
       [rhs-scale  (hip-extract-splat-scale %rhs_scale)]
       [out-scale  (hip-extract-splat-scale %out_scale)]
       [lhs-zp     (hip-extract-qdq-zeropoint-i64 %dq-lhs-op 0)]
       [rhs-zp     (hip-extract-qdq-zeropoint-i64 %dq-rhs-op 0)]
       [out-zp     (hip-extract-qdq-zeropoint-i64 op 0)]
       [%init      (hip-build-init rewriter !out-type %prod_init)])
    :rewrite %q :with
      (%result = hip.qmul (%ctx %lhs %rhs %init)
               ("lhs_scale"    = lhs-scale :f32)
               ("rhs_scale"    = rhs-scale :f32)
               ("output_scale" = out-scale :f32)
               ("lhs_zp"       = lhs-zp   :i64)
               ("rhs_zp"       = rhs-zp   :i64)
               ("output_zp"    = out-zp   :i64)
               -> !out-type))

  ) ;; end library (passes hip-fusion qmul)

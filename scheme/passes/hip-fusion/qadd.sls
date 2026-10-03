#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (passes hip-fusion qadd) — Pattern 1: QAdd  (benefit 10)
;; dq × 2 → hip.add → hip.quantize_linear  ⟹  hip.qadd
;;
;; Scale operands are matched structurally as hip.constant ops so the pattern
;; engine verifies the op name; :where only checks the "value" attr is splat.
;;
;; Zero-point operands are matched with (:optional %zp_val) — the DDR binds
;; the variable when the operand is present (5-operand form) and leaves it
;; unbound-value? when absent (4-operand form).  This eliminates the need for
;; hip-extractable-qdq-zeropoint? guards.  Extraction in :then-let uses
;; unbound-value? to distinguish absent (→ 0) from present (→ splat integer).
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion qadd)
  (export hip-qadd-fusion)

  (import (except (rnrs) =)
          (mlir core ir)
          (mlir hip fusion)
          (mlir ddr)
          (passes hip-fusion helpers))

  ;; Extract the i64 zero-point value from a bound optional zp Value, or 0 if absent.
  (define (extract-zp zp-val)
    (if (unbound-value? zp-val)
        0
        (mlir-attr-splat-int-value
          (mlir-operation-get-attribute (mlir-value-get-defining-op zp-val) "value")
          0)))

  (define-rewrite-pattern (hip-qadd-fusion op rewriter)
    :if-match
        %q        = hip.quantize_linear   (%ctx %sum %out_scale (:optional %out_zp) %q_init)
        %out_scale = hip.constant         ()
                       :where (mlir-attr-is-splat (:attr "value"))
        %sum      = hip.add               (%ctx %dq_lhs %dq_rhs %sum_init)
                       :where (and (hip-value-single-use? %sum)
                                   (hip-can-build-init? op %sum_init))
        %dq_lhs   = hip.dequantize_linear (%ctx %lhs %lhs_scale (:optional %lhs_zp) %dq_lhs_init)
        %lhs_scale = hip.constant         ()
                       :where (mlir-attr-is-splat (:attr "value"))
        %dq_rhs   = hip.dequantize_linear (%ctx %rhs %rhs_scale (:optional %rhs_zp) %dq_rhs_init)
        %rhs_scale = hip.constant         ()
                       :where (mlir-attr-is-splat (:attr "value"))
    :then-let
        ([!out-type (mlir-value-get-type %q)]
         [lhs-scale (hip-extract-splat-scale %lhs_scale)]
         [rhs-scale (hip-extract-splat-scale %rhs_scale)]
         [out-scale (hip-extract-splat-scale %out_scale)]
         [lhs-zp    (extract-zp %lhs_zp)]
         [rhs-zp    (extract-zp %rhs_zp)]
         [out-zp    (extract-zp %out_zp)]
         [%init     (hip-build-init rewriter !out-type %sum_init)])
    :rewrite %q :with
        (%result = (let ([new-op (mlir-build-operation "hip.qadd"
                                   (list %ctx %lhs %rhs %init)
                                   (list !out-type))])
                     (set-qdq-scale-zp-attrs! new-op lhs-scale lhs-zp
                                                     rhs-scale rhs-zp
                                                     out-scale out-zp)
                     (mlir-operation-get-result new-op 0))))

) ;; end library (passes hip-fusion qadd)

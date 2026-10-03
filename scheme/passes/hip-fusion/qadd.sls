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
;; Scale operands are matched structurally as hip.constant ops: the pattern
;; engine checks the op name, so :where only needs to verify the "value" attr
;; is splat.  Note: in DDR, op always refers to the ROOT matched op
;; (hip.quantize_linear here), so we use mlir-value-get-defining-op on the
;; scale Value to reach the constant op for the attr check.
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion qadd)
  (export hip-qadd-fusion)

  (import (except (rnrs) =)
          (mlir core ir)
          (mlir hip fusion)
          (mlir ddr)
          (passes hip-fusion helpers))

  (define (splat-attr? val)
    (mlir-attr-is-splat
      (mlir-operation-get-attribute (mlir-value-get-defining-op val) "value")))

  (define-rewrite-pattern (hip-qadd-fusion op rewriter)
    :if-match
        %q         = hip.quantize_linear   (%ctx %sum %out_scale)
                       :where (and (splat-attr? %out_scale)
                                   (hip-extractable-qdq-zeropoint? op))
        %out_scale = hip.constant          ()
        %sum       = hip.add               (%ctx %dq_lhs %dq_rhs %sum_init)
                       :where (and (hip-value-single-use? %sum)
                                   (hip-can-build-init? op %sum_init))
        %dq_lhs    = hip.dequantize_linear (%ctx %lhs %lhs_scale)
                       :where (and (splat-attr? %lhs_scale)
                                   (hip-extractable-qdq-zeropoint?
                                     (mlir-value-get-defining-op %dq_lhs)))
        %lhs_scale = hip.constant          ()
        %dq_rhs    = hip.dequantize_linear (%ctx %rhs %rhs_scale)
                       :where (and (splat-attr? %rhs_scale)
                                   (hip-extractable-qdq-zeropoint?
                                     (mlir-value-get-defining-op %dq_rhs)))
        %rhs_scale = hip.constant          ()
    :then-let
        ([!out-type  (mlir-value-get-type %q)]
         [%dq-lhs-op (mlir-value-get-defining-op %dq_lhs)]
         [%dq-rhs-op (mlir-value-get-defining-op %dq_rhs)]
         [lhs-scale  (hip-extract-splat-scale %lhs_scale)]
         [rhs-scale  (hip-extract-splat-scale %rhs_scale)]
         [out-scale  (hip-extract-splat-scale %out_scale)]
         [lhs-zp     (hip-extract-qdq-zeropoint-i64 %dq-lhs-op 0)]
         [rhs-zp     (hip-extract-qdq-zeropoint-i64 %dq-rhs-op 0)]
         [out-zp     (hip-extract-qdq-zeropoint-i64 op 0)]
         [%init      (hip-build-init rewriter !out-type %sum_init)])
    :rewrite %q :with
        (%result = (let ([new-op (mlir-build-operation "hip.qadd"
                                   (list %ctx %lhs %rhs %init)
                                   (list !out-type))])
                     (set-qdq-scale-zp-attrs! new-op lhs-scale lhs-zp
                                                     rhs-scale rhs-zp
                                                     out-scale out-zp)
                     (mlir-operation-get-result new-op 0))))

) ;; end library (passes hip-fusion qadd)

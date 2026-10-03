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
          (rename (only (rnrs) =) (= num=))
          (mlir core ir)
          (mlir hip fusion)
          (mlir ddr))

  ;; #t when a Value has exactly one use (safe to fuse without keeping the chain alive).
  (define (single-consumer? val)
    (num= (mlir-value-num-uses val) 1))

  ;; #t when two Value* have the same tensor rank.
  (define (same-rank? a b)
    (define (rank x) (mlir-type-get-rank (mlir-value-get-type x)))
    (num= (rank a) (rank b)))

  ;; Build a FloatAttr<f32> from the splat value of a hip.constant scale.
  ;; Uses current-mlir-context — no explicit ctx needed.
  (define (scale-attr scale-val)
    (mlir-make-attr :f32
      (mlir-attr-into
        (mlir-operation-get-attribute (mlir-value-get-defining-op scale-val) "value")
        :splat-float)))

  ;; Build an IntegerAttr<i64> for the zero-point.
  ;; Present: extract the splat integer from the hip.constant.
  ;; Absent:  zero (default zero-point).
  ;; Uses current-mlir-context — no explicit ctx needed.
  (define (zp-attr zp-val)
    (mlir-make-attr :i64
      (if (unbound-value? zp-val)
          0
          (mlir-attr-into
            (mlir-operation-get-attribute (mlir-value-get-defining-op zp-val) "value")
            :splat-integer))))

  (define-rewrite-pattern (hip-qadd-fusion op rewriter)
    :if-match
        %lhs_scale = hip.constant          ()
                       :where (mlir-attr-isa (:attr "value") :dense-elements-splat)
        %dq_lhs    = hip.dequantize_linear (%ctx %lhs %lhs_scale (:optional %lhs_zp) %dq_lhs_init)
        %rhs_scale = hip.constant          ()
                       :where (mlir-attr-isa (:attr "value") :dense-elements-splat)
        %dq_rhs    = hip.dequantize_linear (%ctx %rhs %rhs_scale (:optional %rhs_zp) %dq_rhs_init)
        %out_scale = hip.constant          ()
                       :where (mlir-attr-isa (:attr "value") :dense-elements-splat)
        %sum       = hip.add               (%ctx %dq_lhs %dq_rhs %sum_init)
                       :where (and (single-consumer? %sum)
                                   (same-rank? %q %sum_init))
        %q         = hip.quantize_linear   (%ctx %sum %out_scale (:optional %out_zp) %q_init)
    :then-let
        ([!out-type  (mlir-value-get-type %q)]
         [lhs-scale  (scale-attr %lhs_scale)]
         [rhs-scale  (scale-attr %rhs_scale)]
         [out-scale  (scale-attr %out_scale)]
         [lhs-zp     (zp-attr %lhs_zp)]
         [rhs-zp     (zp-attr %rhs_zp)]
         [out-zp     (zp-attr %out_zp)]
         [%init      (hip-build-init rewriter !out-type %sum_init)])
    :rewrite %q :with
        (%result = hip.qadd (%ctx %lhs %rhs %init)
                    ("lhs_scale"    = lhs-scale)
                    ("lhs_zp"       = lhs-zp)
                    ("rhs_scale"    = rhs-scale)
                    ("rhs_zp"       = rhs-zp)
                    ("output_scale" = out-scale)
                    ("output_zp"    = out-zp)
                    -> !out-type))

) ;; end library (passes hip-fusion qadd)

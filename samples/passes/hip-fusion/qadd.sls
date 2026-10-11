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
;; Scale and zero-point operands are matched structurally as hip.constant ops.
;; hip.dequantize_linear and hip.quantize_linear always carry an explicit
;; zero-point operand and do not use operandSegmentSizes, so all operands
;; are matched as required.  Extraction of the splat value happens in :then-let.
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion qadd)
  (export hip-qadd-fusion)

  (import (except (rnrs) =)
          (rename (only (rnrs) =) (= num=))

          (only (mlir IR Value)
                mlir::Value::getDefiningOp
                mlir::Value::getType
                mlir::Value::getUses)
          (only (mlir IR BuiltinAttributes)
                mlir::FloatAttr::get<f32>
                mlir::IntegerAttr::get<i64>
                mlir::DenseElementsAttr::isSplat
                mlir::DenseElementsAttr::getSplatValue<APFloat>
                mlir::DenseElementsAttr::getSplatValue<APInt>)
          (crest)
          (only (mlir IR Operation)
                mlir::Operation::getAttr)

          (only (mlir IR BuiltinTypes)
                mlir::RankedTensorType::getRank))

  ;; #t when a Value has exactly one use (safe to fuse without keeping the chain alive).
  (define (single-consumer? val)
    (num= (mlir::Value::getUses val) 1))

  ;; #t when two Value* have the same tensor rank.
  (define (same-rank? a b)
    (define (rank x) (mlir::RankedTensorType::getRank (mlir::Value::getType x)))
    (num= (rank a) (rank b)))

  ;; Build a FloatAttr<f32> from the splat value of a hip.constant scale.
  ;; Uses current-MLIRContext — no explicit ctx needed.
  (define (scale-attr scale-val)
    (mlir::FloatAttr::get<f32>
     (mlir::DenseElementsAttr::getSplatValue<APFloat>
      (mlir::Operation::getAttr (mlir::Value::getDefiningOp scale-val) "value"))))

  ;; Build an IntegerAttr<i64> for the zero-point.
  ;; Present: extract the splat integer from the hip.constant.
  ;; Absent:  zero (default zero-point).
  ;; Uses current-MLIRContext — no explicit ctx needed.
  (define (zp-attr zp-val)
    (mlir::IntegerAttr::get<i64>
     (mlir::DenseElementsAttr::getSplatValue<APInt>
      (mlir::Operation::getAttr (mlir::Value::getDefiningOp zp-val) "value"))))

  (define-rewrite-pattern (hip-qadd-fusion op rewriter)
    :if-match
      %lhs_scale = hip.constant          ()
        :where (mlir::DenseElementsAttr::isSplat (:attr "value"))
      %dq_lhs    = hip.dequantize_linear (%ctx %lhs %lhs_scale %lhs_zp %dq_lhs_init)
      %rhs_scale = hip.constant          ()
        :where (mlir::DenseElementsAttr::isSplat (:attr "value"))
      %dq_rhs    = hip.dequantize_linear (%ctx %rhs %rhs_scale %rhs_zp %dq_rhs_init)
      %out_scale = hip.constant          ()
        :where (mlir::DenseElementsAttr::isSplat (:attr "value"))
      %sum       = hip.add               (%ctx %dq_lhs %dq_rhs %sum_init)
        :where (and (single-consumer? %sum)
                    (same-rank? %q %sum_init))
      %q         = hip.quantize_linear   (%ctx %sum %out_scale %out_zp %q_init)
    :then-let
      ([!out-type  (mlir::Value::getType %q)]
       [lhs-scale  (scale-attr %lhs_scale)]
       [rhs-scale  (scale-attr %rhs_scale)]
       [out-scale  (scale-attr %out_scale)]
       [lhs-zp     (zp-attr %lhs_zp)]
       [rhs-zp     (zp-attr %rhs_zp)]
       [out-zp     (zp-attr %out_zp)])
    :rewrite %q :with
      (%init   = tensor.empty () -> !out-type)
      (%result = hip.qadd (%ctx %lhs %rhs %init)
               ("lhs_scale"    = lhs-scale)
               ("lhs_zp"       = lhs-zp)
               ("rhs_scale"    = rhs-scale)
               ("rhs_zp"       = rhs-zp)
               ("output_scale" = out-scale)
               ("output_zp"    = out-zp)
               -> !out-type))

  ) ;; end library (passes hip-fusion qadd)

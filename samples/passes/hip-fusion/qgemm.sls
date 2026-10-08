#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (passes hip-fusion qgemm) — Patterns 6–9: QGemm variants
;;
;;   Pattern 6: per-tensor with bias               (benefit 10)
;;   Pattern 7: per-tensor no bias                 (benefit 10)
;;   Pattern 8: per-channel weight with bias       (benefit  9)
;;   Pattern 9: per-channel weight no bias         (benefit  9)
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion qgemm)
  (export hip-qgemm-fusion
          hip-qgemm-no-bias
          hip-qgemm-per-channel
          hip-qgemm-no-bias-per-channel)

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
          (only (mlir IR Value) mlir::Value::getDefiningOp)
          (only (mlir IR Operation)
                mlir::Operation::setAttr! mlir::Operation::getAttrOfType<IntegerAttr>)
          (only (mlir IR BuiltinAttributes)
                mlir::FloatAttr::get<f32>)
          )

  ;;===--------------------------------------------------------------------===;;
  ;; Pattern 6: QGemm per-tensor with bias  (benefit 10)
  ;;===--------------------------------------------------------------------===;;

  (define-rewrite-pattern (hip-qgemm-fusion op rewriter)
    :if-match
      %q    = hip.quantize_linear   (%ctx %gemm %y_scale)
        :where (and (hip-splat-scale? %y_scale)
                    (hip-qdq-quantized-width? op '(8 16))
                    (hip-extractable-qdq-zeropoint? op))
      %gemm = hip.gemm              (%ctx %dq_a %dq_b %dq_c %gemm_init)
        :where (and (hip-value-single-use? %gemm)
                    (hip-can-build-init? op %gemm_init))
      %dq_a = hip.dequantize_linear (%ctx %a %a_scale)
        :where (and (hip-qdq-quantized-width?
                     (mlir::Value::getDefiningOp %dq_a) '(8 16))
                    (hip-splat-scale? %a_scale)
                    (hip-extractable-qdq-zeropoint?
                     (mlir::Value::getDefiningOp %dq_a)))
      %dq_b = hip.dequantize_linear (%ctx %b %b_scale)
        :where (and (hip-qdq-quantized-width?
                     (mlir::Value::getDefiningOp %dq_b) '(8))
                    (hip-splat-scale? %b_scale)
                    (hip-extractable-qdq-zeropoint?
                     (mlir::Value::getDefiningOp %dq_b)))
      %dq_c = hip.dequantize_linear (%ctx %c %c_scale)
        :where (and (hip-qdq-quantized-width?
                     (mlir::Value::getDefiningOp %dq_c) '(8 16 32))
                    (hip-splat-scale? %c_scale)
                    (hip-extractable-qdq-zeropoint?
                     (mlir::Value::getDefiningOp %dq_c)))
    :then-let
      ([!y-type   (mlir::Value::getType %q)]
       [%dq-a-op  (mlir::Value::getDefiningOp %dq_a)]
       [%dq-b-op  (mlir::Value::getDefiningOp %dq_b)]
       [%dq-c-op  (mlir::Value::getDefiningOp %dq_c)]
       [%gemm-op  (mlir::Value::getDefiningOp %gemm)]
       [a-scale   (hip-extract-splat-scale %a_scale)]
       [b-scale   (hip-extract-splat-scale %b_scale)]
       [c-scale   (hip-extract-splat-scale %c_scale)]
       [y-scale   (hip-extract-splat-scale %y_scale)]
       [a-zp      (hip-extract-qdq-zeropoint-i64 %dq-a-op 0)]
       [b-zp      (hip-extract-qdq-zeropoint-i64 %dq-b-op 0)]
       [c-zp      (hip-extract-qdq-zeropoint-i64 %dq-c-op 0)]
       [y-zp      (hip-extract-qdq-zeropoint-i64 op 0)]
       [b-bits    (hip-qdq-value-bits-c %dq-b-op)]
       [alpha     (op-get-f32-attr %gemm-op "alpha")]
       [beta      (op-get-f32-attr %gemm-op "beta")]
       [trans-a   (mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transA" 0)]
       [trans-b   (mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transB" 0)]
       [%init     (hip-build-init rewriter !y-type %gemm_init)])
    :rewrite %q :with
      (%gemm-result = hip.qgemm (%ctx %a %b %c %init)
                    ("operandSegmentSizes" = '(1 1 1 0 0 1 1) :i32-array)
                    ("A_scale"      = a-scale :f32)
                    ("A_zero_point" = a-zp    :i64)
                    ("B_scale"      = b-scale :f32)
                    ("B_zero_point" = b-zp    :i64)
                    ("B_bits"       = b-bits  :i64)
                    ("C_scale"      = c-scale :f32)
                    ("C_zero_point" = c-zp    :i64)
                    ("Y_scale"      = y-scale :f32)
                    ("Y_zero_point" = y-zp    :i64)
                    ("transA"       = trans-a :i64)
                    ("transB"       = trans-b :i64)
                    -> !y-type)
      (%result = (let ([new-op (mlir::Value::getDefiningOp %gemm-result)])
                   (unless (nan? alpha) (mlir::Operation::setAttr! new-op "alpha" (mlir::FloatAttr::get<f32> alpha)))
                   (unless (nan? beta)  (mlir::Operation::setAttr! new-op "beta" (mlir::FloatAttr::get<f32>  beta)))
                   %gemm-result)))

  ;;===--------------------------------------------------------------------===;;
  ;; Pattern 7: QGemm per-tensor no bias  (benefit 10)
  ;;===--------------------------------------------------------------------===;;

  (define-rewrite-pattern (hip-qgemm-no-bias op rewriter)
    :if-match
      %q    = hip.quantize_linear   (%ctx %gemm %y_scale)
        :where (and (hip-splat-scale? %y_scale)
                    (hip-qdq-quantized-width? op '(8 16))
                    (hip-extractable-qdq-zeropoint? op))
      %gemm = hip.gemm              (%ctx %dq_a %dq_b %gemm_init)
        :where (and (hip-value-single-use? %gemm)
                    (hip-can-build-init? op %gemm_init))
      %dq_a = hip.dequantize_linear (%ctx %a %a_scale)
        :where (and (hip-qdq-quantized-width?
                     (mlir::Value::getDefiningOp %dq_a) '(8 16))
                    (hip-splat-scale? %a_scale)
                    (hip-extractable-qdq-zeropoint?
                     (mlir::Value::getDefiningOp %dq_a)))
      %dq_b = hip.dequantize_linear (%ctx %b %b_scale)
        :where (and (hip-qdq-quantized-width?
                     (mlir::Value::getDefiningOp %dq_b) '(8))
                    (hip-splat-scale? %b_scale)
                    (hip-extractable-qdq-zeropoint?
                     (mlir::Value::getDefiningOp %dq_b)))
    :then-let
      ([!y-type  (mlir::Value::getType %q)]
       [%dq-a-op (mlir::Value::getDefiningOp %dq_a)]
       [%dq-b-op (mlir::Value::getDefiningOp %dq_b)]
       [%gemm-op (mlir::Value::getDefiningOp %gemm)]
       [a-scale  (hip-extract-splat-scale %a_scale)]
       [b-scale  (hip-extract-splat-scale %b_scale)]
       [y-scale  (hip-extract-splat-scale %y_scale)]
       [a-zp     (hip-extract-qdq-zeropoint-i64 %dq-a-op 0)]
       [b-zp     (hip-extract-qdq-zeropoint-i64 %dq-b-op 0)]
       [y-zp     (hip-extract-qdq-zeropoint-i64 op 0)]
       [b-bits   (hip-qdq-value-bits-c %dq-b-op)]
       [alpha    (op-get-f32-attr %gemm-op "alpha")]
       [trans-a  (mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transA" 0)]
       [trans-b  (mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transB" 0)]
       [%init    (hip-build-init rewriter !y-type %gemm_init)])
    :rewrite %q :with
      (%gemm-result = hip.qgemm (%ctx %a %b %init)
                    ("operandSegmentSizes" = '(1 1 1 0 0 0 1) :i32-array)
                    ("A_scale"      = a-scale :f32)
                    ("A_zero_point" = a-zp    :i64)
                    ("B_scale"      = b-scale :f32)
                    ("B_zero_point" = b-zp    :i64)
                    ("B_bits"       = b-bits  :i64)
                    ("Y_scale"      = y-scale :f32)
                    ("Y_zero_point" = y-zp    :i64)
                    ("transA"       = trans-a :i64)
                    ("transB"       = trans-b :i64)
                    -> !y-type)
      (%result = (let ([new-op (mlir::Value::getDefiningOp %gemm-result)])
                   (unless (nan? alpha) (mlir::Operation::setAttr! new-op "alpha" (mlir::FloatAttr::get<f32> alpha)))
                   %gemm-result)))

  ;;===--------------------------------------------------------------------===;;
  ;; Pattern 8: QGemm per-channel weight with bias  (benefit 9)
  ;;===--------------------------------------------------------------------===;;

  (define-rewrite-pattern (hip-qgemm-per-channel op rewriter)
    :if-match
      %q    = hip.quantize_linear   (%ctx %gemm %y_scale)
        :where (and (hip-splat-scale? %y_scale)
                    (hip-qdq-quantized-width? op '(8 16))
                    (hip-extractable-qdq-zeropoint? op))
      %gemm = hip.gemm              (%ctx %dq_a %dq_b %dq_c %gemm_init)
        :where (and (hip-value-single-use? %gemm)
                    (hip-can-build-init? op %gemm_init))
      %dq_a = hip.dequantize_linear (%ctx %a %a_scale)
        :where (and (hip-qdq-quantized-width?
                     (mlir::Value::getDefiningOp %dq_a) '(8 16))
                    (hip-splat-scale? %a_scale)
                    (hip-extractable-qdq-zeropoint?
                     (mlir::Value::getDefiningOp %dq_a)))
      %dq_b = hip.dequantize_linear (%ctx %b %b_scales %b_zps %b_init)
        :where (hip-per-channel-weight?
                (mlir::Value::getDefiningOp %dq_b)
                (mlir::Value::getDefiningOp %gemm))
      %dq_c = hip.dequantize_linear (%ctx %c %c_scale)
        :where (and (hip-qdq-quantized-width?
                     (mlir::Value::getDefiningOp %dq_c) '(8 16 32))
                    (hip-splat-scale? %c_scale)
                    (hip-extractable-qdq-zeropoint?
                     (mlir::Value::getDefiningOp %dq_c)))
    :then-let
      ([!y-type  (mlir::Value::getType %q)]
       [%dq-a-op (mlir::Value::getDefiningOp %dq_a)]
       [%dq-b-op (mlir::Value::getDefiningOp %dq_b)]
       [%dq-c-op (mlir::Value::getDefiningOp %dq_c)]
       [%gemm-op (mlir::Value::getDefiningOp %gemm)]
       [a-scale  (hip-extract-splat-scale %a_scale)]
       [c-scale  (hip-extract-splat-scale %c_scale)]
       [y-scale  (hip-extract-splat-scale %y_scale)]
       [a-zp     (hip-extract-qdq-zeropoint-i64 %dq-a-op 0)]
       [c-zp     (hip-extract-qdq-zeropoint-i64 %dq-c-op 0)]
       [y-zp     (hip-extract-qdq-zeropoint-i64 op 0)]
       [b-bits   (hip-qdq-value-bits-c %dq-b-op)]
       [alpha    (op-get-f32-attr %gemm-op "alpha")]
       [beta     (op-get-f32-attr %gemm-op "beta")]
       [trans-a  (mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transA" 0)]
       [trans-b  (mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transB" 0)]
       [%init    (hip-build-init rewriter !y-type %gemm_init)])
    :rewrite %q :with
      (%gemm-result = hip.qgemm (%ctx %a %b %b_scales %b_zps %c %init)
                    ("operandSegmentSizes" = '(1 1 1 1 1 1 1) :i32-array)
                    ("A_scale"      = a-scale :f32)
                    ("A_zero_point" = a-zp    :i64)
                    ("B_bits"       = b-bits  :i64)
                    ("C_scale"      = c-scale :f32)
                    ("C_zero_point" = c-zp    :i64)
                    ("Y_scale"      = y-scale :f32)
                    ("Y_zero_point" = y-zp    :i64)
                    ("transA"       = trans-a :i64)
                    ("transB"       = trans-b :i64)
                    -> !y-type)
      (%result = (let ([new-op (mlir::Value::getDefiningOp %gemm-result)])
                   (unless (nan? alpha) (mlir::Operation::setAttr! new-op "alpha" (mlir::FloatAttr::get<f32> alpha)))
                   (unless (nan? beta)  (mlir::Operation::setAttr! new-op "beta" (mlir::FloatAttr::get<f32>  beta)))
                   %gemm-result)))

  ;;===--------------------------------------------------------------------===;;
  ;; Pattern 9: QGemm per-channel no bias  (benefit 9)
  ;;===--------------------------------------------------------------------===;;

  (define-rewrite-pattern (hip-qgemm-no-bias-per-channel op rewriter)
    :if-match
      %q    = hip.quantize_linear   (%ctx %gemm %y_scale)
        :where (and (hip-splat-scale? %y_scale)
                    (hip-qdq-quantized-width? op '(8 16))
                    (hip-extractable-qdq-zeropoint? op))
      %gemm = hip.gemm              (%ctx %dq_a %dq_b %gemm_init)
        :where (and (hip-value-single-use? %gemm)
                    (hip-can-build-init? op %gemm_init))
      %dq_a = hip.dequantize_linear (%ctx %a %a_scale)
        :where (and (hip-qdq-quantized-width?
                     (mlir::Value::getDefiningOp %dq_a) '(8 16))
                    (hip-splat-scale? %a_scale)
                    (hip-extractable-qdq-zeropoint?
                     (mlir::Value::getDefiningOp %dq_a)))
      %dq_b = hip.dequantize_linear (%ctx %b %b_scales %b_zps %b_init)
        :where (hip-per-channel-weight?
                (mlir::Value::getDefiningOp %dq_b)
                (mlir::Value::getDefiningOp %gemm))
    :then-let
      ([!y-type  (mlir::Value::getType %q)]
       [%dq-a-op (mlir::Value::getDefiningOp %dq_a)]
       [%dq-b-op (mlir::Value::getDefiningOp %dq_b)]
       [%gemm-op (mlir::Value::getDefiningOp %gemm)]
       [a-scale  (hip-extract-splat-scale %a_scale)]
       [y-scale  (hip-extract-splat-scale %y_scale)]
       [a-zp     (hip-extract-qdq-zeropoint-i64 %dq-a-op 0)]
       [y-zp     (hip-extract-qdq-zeropoint-i64 op 0)]
       [b-bits   (hip-qdq-value-bits-c %dq-b-op)]
       [alpha    (op-get-f32-attr %gemm-op "alpha")]
       [trans-a  (mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transA" 0)]
       [trans-b  (mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transB" 0)]
       [%init    (hip-build-init rewriter !y-type %gemm_init)])
    :rewrite %q :with
      (%gemm-result = hip.qgemm (%ctx %a %b %b_scales %b_zps %init)
                    ("operandSegmentSizes" = '(1 1 1 1 1 0 1) :i32-array)
                    ("A_scale"      = a-scale :f32)
                    ("A_zero_point" = a-zp    :i64)
                    ("B_bits"       = b-bits  :i64)
                    ("Y_scale"      = y-scale :f32)
                    ("Y_zero_point" = y-zp    :i64)
                    ("transA"       = trans-a :i64)
                    ("transB"       = trans-b :i64)
                    -> !y-type)
      (%result = (let ([new-op (mlir::Value::getDefiningOp %gemm-result)])
                   (unless (nan? alpha) (mlir::Operation::setAttr! new-op "alpha" (mlir::FloatAttr::get<f32> alpha)))
                   %gemm-result)))

  ) ;; end library (passes hip-fusion qgemm)

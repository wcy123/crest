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
          (rename (only (mlir ir operation)
                       mlir::Operation::getAttrOfType<IntegerAttr>
                       mlir::Operation::getResult
                       operation-set-f32-attr!
                       operation-set-i64-attr!)
                 (mlir::Operation::getAttrOfType<IntegerAttr> mlir-mlir::Operation::getAttrOfType<IntegerAttr>)
                 (mlir::Operation::getResult       mlir-mlir::Operation::getResult)
                 (operation-set-f32-attr!    mlir-operation-set-f32-attr!)
                 (operation-set-i64-attr!    mlir-operation-set-i64-attr!))
          (rename (mlir ir value)
            (get-defining-op   mlir-mlir::Value::getDefiningOp)
            (get-type          mlir-mlir::Value::getType))
          (only (mlir core builder) mlir-build-operation)
          (mlir dialects builtin)
          (mlir transforms dialect-conversion)
          (passes hip-fusion fusion)
          (crest)
          (passes hip-fusion helpers))

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
                                (mlir-mlir::Value::getDefiningOp %dq_a) '(8 16))
                              (hip-splat-scale? %a_scale)
                              (hip-extractable-qdq-zeropoint?
                                (mlir-mlir::Value::getDefiningOp %dq_a)))
        %dq_b = hip.dequantize_linear (%ctx %b %b_scale)
                  :where (and (hip-qdq-quantized-width?
                                (mlir-mlir::Value::getDefiningOp %dq_b) '(8))
                              (hip-splat-scale? %b_scale)
                              (hip-extractable-qdq-zeropoint?
                                (mlir-mlir::Value::getDefiningOp %dq_b)))
        %dq_c = hip.dequantize_linear (%ctx %c %c_scale)
                  :where (and (hip-qdq-quantized-width?
                                (mlir-mlir::Value::getDefiningOp %dq_c) '(8 16 32))
                              (hip-splat-scale? %c_scale)
                              (hip-extractable-qdq-zeropoint?
                                (mlir-mlir::Value::getDefiningOp %dq_c)))
    :then-let
        ([!y-type   (mlir-mlir::Value::getType %q)]
         [%dq-a-op  (mlir-mlir::Value::getDefiningOp %dq_a)]
         [%dq-b-op  (mlir-mlir::Value::getDefiningOp %dq_b)]
         [%dq-c-op  (mlir-mlir::Value::getDefiningOp %dq_c)]
         [%gemm-op  (mlir-mlir::Value::getDefiningOp %gemm)]
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
         [trans-a   (mlir-mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transA" 0)]
         [trans-b   (mlir-mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transB" 0)]
         [%init     (hip-build-init rewriter !y-type %gemm_init)])
    :rewrite %q :with
        (%result = (let ([new-op (mlir-build-operation "hip.qgemm"
                                   (list %ctx %a %b %c %init)
                                   (list !y-type))])
                     (mlir-operation-set-dense-i32-array! new-op "operandSegmentSizes"
                                                          '(1 1 1 0 0 1 1))
                     (mlir-operation-set-f32-attr! new-op "A_scale"      a-scale)
                     (mlir-operation-set-i64-attr! new-op "A_zero_point" a-zp)
                     (mlir-operation-set-f32-attr! new-op "B_scale"      b-scale)
                     (mlir-operation-set-i64-attr! new-op "B_zero_point" b-zp)
                     (mlir-operation-set-i64-attr! new-op "B_bits"       b-bits)
                     (mlir-operation-set-f32-attr! new-op "C_scale"      c-scale)
                     (mlir-operation-set-i64-attr! new-op "C_zero_point" c-zp)
                     (mlir-operation-set-f32-attr! new-op "Y_scale"      y-scale)
                     (mlir-operation-set-i64-attr! new-op "Y_zero_point" y-zp)
                     (unless (nan? alpha) (mlir-operation-set-f32-attr! new-op "alpha" alpha))
                     (unless (nan? beta)  (mlir-operation-set-f32-attr! new-op "beta"  beta))
                     (mlir-operation-set-i64-attr! new-op "transA"       trans-a)
                     (mlir-operation-set-i64-attr! new-op "transB"       trans-b)
                     (mlir-mlir::Operation::getResult new-op 0))))

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
                                (mlir-mlir::Value::getDefiningOp %dq_a) '(8 16))
                              (hip-splat-scale? %a_scale)
                              (hip-extractable-qdq-zeropoint?
                                (mlir-mlir::Value::getDefiningOp %dq_a)))
        %dq_b = hip.dequantize_linear (%ctx %b %b_scale)
                  :where (and (hip-qdq-quantized-width?
                                (mlir-mlir::Value::getDefiningOp %dq_b) '(8))
                              (hip-splat-scale? %b_scale)
                              (hip-extractable-qdq-zeropoint?
                                (mlir-mlir::Value::getDefiningOp %dq_b)))
    :then-let
        ([!y-type  (mlir-mlir::Value::getType %q)]
         [%dq-a-op (mlir-mlir::Value::getDefiningOp %dq_a)]
         [%dq-b-op (mlir-mlir::Value::getDefiningOp %dq_b)]
         [%gemm-op (mlir-mlir::Value::getDefiningOp %gemm)]
         [a-scale  (hip-extract-splat-scale %a_scale)]
         [b-scale  (hip-extract-splat-scale %b_scale)]
         [y-scale  (hip-extract-splat-scale %y_scale)]
         [a-zp     (hip-extract-qdq-zeropoint-i64 %dq-a-op 0)]
         [b-zp     (hip-extract-qdq-zeropoint-i64 %dq-b-op 0)]
         [y-zp     (hip-extract-qdq-zeropoint-i64 op 0)]
         [b-bits   (hip-qdq-value-bits-c %dq-b-op)]
         [alpha    (op-get-f32-attr %gemm-op "alpha")]
         [trans-a  (mlir-mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transA" 0)]
         [trans-b  (mlir-mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transB" 0)]
         [%init    (hip-build-init rewriter !y-type %gemm_init)])
    :rewrite %q :with
        (%result = (let ([new-op (mlir-build-operation "hip.qgemm"
                                   (list %ctx %a %b %init)
                                   (list !y-type))])
                     (mlir-operation-set-dense-i32-array! new-op "operandSegmentSizes"
                                                          '(1 1 1 0 0 0 1))
                     (mlir-operation-set-f32-attr! new-op "A_scale"      a-scale)
                     (mlir-operation-set-i64-attr! new-op "A_zero_point" a-zp)
                     (mlir-operation-set-f32-attr! new-op "B_scale"      b-scale)
                     (mlir-operation-set-i64-attr! new-op "B_zero_point" b-zp)
                     (mlir-operation-set-i64-attr! new-op "B_bits"       b-bits)
                     (mlir-operation-set-f32-attr! new-op "Y_scale"      y-scale)
                     (mlir-operation-set-i64-attr! new-op "Y_zero_point" y-zp)
                     (unless (nan? alpha) (mlir-operation-set-f32-attr! new-op "alpha" alpha))
                     (mlir-operation-set-i64-attr! new-op "transA"       trans-a)
                     (mlir-operation-set-i64-attr! new-op "transB"       trans-b)
                     (mlir-mlir::Operation::getResult new-op 0))))

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
                                (mlir-mlir::Value::getDefiningOp %dq_a) '(8 16))
                              (hip-splat-scale? %a_scale)
                              (hip-extractable-qdq-zeropoint?
                                (mlir-mlir::Value::getDefiningOp %dq_a)))
        %dq_b = hip.dequantize_linear (%ctx %b %b_scales %b_zps %b_init)
                  :where (hip-per-channel-weight?
                            (mlir-mlir::Value::getDefiningOp %dq_b)
                            (mlir-mlir::Value::getDefiningOp %gemm))
        %dq_c = hip.dequantize_linear (%ctx %c %c_scale)
                  :where (and (hip-qdq-quantized-width?
                                (mlir-mlir::Value::getDefiningOp %dq_c) '(8 16 32))
                              (hip-splat-scale? %c_scale)
                              (hip-extractable-qdq-zeropoint?
                                (mlir-mlir::Value::getDefiningOp %dq_c)))
    :then-let
        ([!y-type  (mlir-mlir::Value::getType %q)]
         [%dq-a-op (mlir-mlir::Value::getDefiningOp %dq_a)]
         [%dq-b-op (mlir-mlir::Value::getDefiningOp %dq_b)]
         [%dq-c-op (mlir-mlir::Value::getDefiningOp %dq_c)]
         [%gemm-op (mlir-mlir::Value::getDefiningOp %gemm)]
         [a-scale  (hip-extract-splat-scale %a_scale)]
         [c-scale  (hip-extract-splat-scale %c_scale)]
         [y-scale  (hip-extract-splat-scale %y_scale)]
         [a-zp     (hip-extract-qdq-zeropoint-i64 %dq-a-op 0)]
         [c-zp     (hip-extract-qdq-zeropoint-i64 %dq-c-op 0)]
         [y-zp     (hip-extract-qdq-zeropoint-i64 op 0)]
         [b-bits   (hip-qdq-value-bits-c %dq-b-op)]
         [alpha    (op-get-f32-attr %gemm-op "alpha")]
         [beta     (op-get-f32-attr %gemm-op "beta")]
         [trans-a  (mlir-mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transA" 0)]
         [trans-b  (mlir-mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transB" 0)]
         [%init    (hip-build-init rewriter !y-type %gemm_init)])
    :rewrite %q :with
        (%result = (let ([new-op (mlir-build-operation "hip.qgemm"
                                   (list %ctx %a %b %b_scales %b_zps %c %init)
                                   (list !y-type))])
                     (mlir-operation-set-dense-i32-array! new-op "operandSegmentSizes"
                                                          '(1 1 1 1 1 1 1))
                     (mlir-operation-set-f32-attr! new-op "A_scale"      a-scale)
                     (mlir-operation-set-i64-attr! new-op "A_zero_point" a-zp)
                     (mlir-operation-set-i64-attr! new-op "B_bits"       b-bits)
                     (mlir-operation-set-f32-attr! new-op "C_scale"      c-scale)
                     (mlir-operation-set-i64-attr! new-op "C_zero_point" c-zp)
                     (mlir-operation-set-f32-attr! new-op "Y_scale"      y-scale)
                     (mlir-operation-set-i64-attr! new-op "Y_zero_point" y-zp)
                     (unless (nan? alpha) (mlir-operation-set-f32-attr! new-op "alpha" alpha))
                     (unless (nan? beta)  (mlir-operation-set-f32-attr! new-op "beta"  beta))
                     (mlir-operation-set-i64-attr! new-op "transA"       trans-a)
                     (mlir-operation-set-i64-attr! new-op "transB"       trans-b)
                     (mlir-mlir::Operation::getResult new-op 0))))

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
                                (mlir-mlir::Value::getDefiningOp %dq_a) '(8 16))
                              (hip-splat-scale? %a_scale)
                              (hip-extractable-qdq-zeropoint?
                                (mlir-mlir::Value::getDefiningOp %dq_a)))
        %dq_b = hip.dequantize_linear (%ctx %b %b_scales %b_zps %b_init)
                  :where (hip-per-channel-weight?
                            (mlir-mlir::Value::getDefiningOp %dq_b)
                            (mlir-mlir::Value::getDefiningOp %gemm))
    :then-let
        ([!y-type  (mlir-mlir::Value::getType %q)]
         [%dq-a-op (mlir-mlir::Value::getDefiningOp %dq_a)]
         [%dq-b-op (mlir-mlir::Value::getDefiningOp %dq_b)]
         [%gemm-op (mlir-mlir::Value::getDefiningOp %gemm)]
         [a-scale  (hip-extract-splat-scale %a_scale)]
         [y-scale  (hip-extract-splat-scale %y_scale)]
         [a-zp     (hip-extract-qdq-zeropoint-i64 %dq-a-op 0)]
         [y-zp     (hip-extract-qdq-zeropoint-i64 op 0)]
         [b-bits   (hip-qdq-value-bits-c %dq-b-op)]
         [alpha    (op-get-f32-attr %gemm-op "alpha")]
         [trans-a  (mlir-mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transA" 0)]
         [trans-b  (mlir-mlir::Operation::getAttrOfType<IntegerAttr> %gemm-op "transB" 0)]
         [%init    (hip-build-init rewriter !y-type %gemm_init)])
    :rewrite %q :with
        (%result = (let ([new-op (mlir-build-operation "hip.qgemm"
                                   (list %ctx %a %b %b_scales %b_zps %init)
                                   (list !y-type))])
                     (mlir-operation-set-dense-i32-array! new-op "operandSegmentSizes"
                                                          '(1 1 1 1 1 0 1))
                     (mlir-operation-set-f32-attr! new-op "A_scale"      a-scale)
                     (mlir-operation-set-i64-attr! new-op "A_zero_point" a-zp)
                     (mlir-operation-set-i64-attr! new-op "B_bits"       b-bits)
                     (mlir-operation-set-f32-attr! new-op "Y_scale"      y-scale)
                     (mlir-operation-set-i64-attr! new-op "Y_zero_point" y-zp)
                     (unless (nan? alpha) (mlir-operation-set-f32-attr! new-op "alpha" alpha))
                     (mlir-operation-set-i64-attr! new-op "transA"       trans-a)
                     (mlir-operation-set-i64-attr! new-op "transB"       trans-b)
                     (mlir-mlir::Operation::getResult new-op 0))))

) ;; end library (passes hip-fusion qgemm)

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (passes hip-fusion qmatmul) — Patterns 3–5: QMatMul variants
;;
;;   Pattern 3: per-tensor A8/A16 × B8            (benefit 10)
;;   Pattern 4: per-column W4, transB=0           (benefit  9)
;;   Pattern 5: per-column W8, transB=0           (benefit  9)
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion qmatmul)
  (export hip-qmatmul-fusion
          hip-qmatmul-per-col-w4
          hip-qmatmul-per-col-w8)

  (import (except (rnrs) =)
          (only (chezscheme) nan?)
          (rename (only (rnrs) =) (= num=))
          (mlir core operation)
          (rename (mlir ir value)
            (get-defining-op   mlir-value-get-defining-op)
            (get-type          mlir-value-get-type))
          (mlir core attribute)
          (only (mlir core builder) mlir-build-operation)
          (mlir dialects builtin)
          (mlir transforms dialect-conversion)
          (passes hip-fusion fusion)
          (crest)
          (passes hip-fusion helpers))

  ;;===--------------------------------------------------------------------===;;
  ;; Pattern 3: QMatMul per-tensor  (benefit 10)
  ;;===--------------------------------------------------------------------===;;

  (define-rewrite-pattern (hip-qmatmul-fusion op rewriter)
    :if-match
        %q      = hip.quantize_linear   (%ctx %matmul %y_scale)
                    :where (and (hip-splat-scale? %y_scale)
                                (hip-qdq-quantized-width? op '(8 16))
                                (hip-extractable-qdq-zeropoint? op))
        %matmul = hip.matmul            (%ctx %dq_a %dq_b %matmul_init)
                    :where (and (hip-value-single-use? %matmul)
                                (hip-can-build-init? op %matmul_init))
        %dq_a   = hip.dequantize_linear (%ctx %a %a_scale)
                    :where (and (hip-qdq-quantized-width?
                                  (mlir-value-get-defining-op %dq_a) '(8 16))
                                (hip-splat-scale? %a_scale)
                                (hip-extractable-qdq-zeropoint?
                                  (mlir-value-get-defining-op %dq_a)))
        %dq_b   = hip.dequantize_linear (%ctx %b %b_scale)
                    :where (and (hip-qdq-quantized-width?
                                  (mlir-value-get-defining-op %dq_b) '(8))
                                (hip-splat-scale? %b_scale)
                                (hip-extractable-qdq-zeropoint?
                                  (mlir-value-get-defining-op %dq_b)))
    :then-let
        ([!y-type    (mlir-value-get-type %q)]
         [%dq-a-op   (mlir-value-get-defining-op %dq_a)]
         [%dq-b-op   (mlir-value-get-defining-op %dq_b)]
         [%mm-op     (mlir-value-get-defining-op %matmul)]
         [a-scale    (hip-extract-splat-scale %a_scale)]
         [b-scale    (hip-extract-splat-scale %b_scale)]
         [y-scale    (hip-extract-splat-scale %y_scale)]
         [a-zp       (hip-extract-qdq-zeropoint-i64 %dq-a-op 0)]
         [b-zp       (hip-extract-qdq-zeropoint-i64 %dq-b-op 0)]
         [y-zp       (hip-extract-qdq-zeropoint-i64 op 0)]
         [trans-a    (mlir-operation-get-integer-attr %mm-op "transA" 0)]
         [trans-b    (mlir-operation-get-integer-attr %mm-op "transB" 0)]
         [%init      (hip-build-init rewriter !y-type %matmul_init)])
    :rewrite %q :with
        (%result = (let ([new-op (mlir-build-operation "hip.qmatmul"
                                   (list %ctx %a %b %init)
                                   (list !y-type))])
                     (mlir-operation-set-f32-attr! new-op "A_scale"       a-scale)
                     (mlir-operation-set-i64-attr! new-op "A_zero_point"  a-zp)
                     (mlir-operation-set-f32-attr! new-op "B_scale"       b-scale)
                     (mlir-operation-set-i64-attr! new-op "B_zero_point"  b-zp)
                     (mlir-operation-set-f32-attr! new-op "Y_scale"       y-scale)
                     (mlir-operation-set-i64-attr! new-op "Y_zero_point"  y-zp)
                     (mlir-operation-set-i64-attr! new-op "transA"        trans-a)
                     (mlir-operation-set-i64-attr! new-op "transB"        trans-b)
                     (mlir-operation-get-result new-op 0))))

  ;;===--------------------------------------------------------------------===;;
  ;; Pattern 4: QMatMul per-column W4  (benefit 9)
  ;;===--------------------------------------------------------------------===;;

  (define-rewrite-pattern (hip-qmatmul-per-col-w4 op rewriter)
    :if-match
        %q      = hip.quantize_linear   (%ctx %matmul %y_scale)
                    :where (and (hip-splat-scale? %y_scale)
                                (hip-qdq-quantized-width? op '(8 16))
                                (hip-extractable-qdq-zeropoint? op))
        %matmul = hip.matmul            (%ctx %dq_a %dq_b %matmul_init)
                    :where (and (hip-value-single-use? %matmul)
                                (hip-can-build-init? op %matmul_init)
                                (num= (mlir-operation-get-integer-attr
                                        (mlir-value-get-defining-op %matmul) "transB" 0)
                                      0))
        %dq_a   = hip.dequantize_linear (%ctx %a %a_scale)
                    :where (and (hip-qdq-quantized-width?
                                  (mlir-value-get-defining-op %dq_a) '(8 16))
                                (hip-splat-scale? %a_scale)
                                (hip-extractable-qdq-zeropoint?
                                  (mlir-value-get-defining-op %dq_a)))
        %dq_b   = hip.dequantize_linear (%ctx %b %b_scales %b_zps %b_init)
                    :where (hip-per-axis-weight?
                              (mlir-value-get-defining-op %dq_b) 2 1 #t)
    :then-let
        ([!y-type    (mlir-value-get-type %q)]
         [%dq-a-op   (mlir-value-get-defining-op %dq_a)]
         [%mm-op     (mlir-value-get-defining-op %matmul)]
         [a-scale    (hip-extract-splat-scale %a_scale)]
         [y-scale    (hip-extract-splat-scale %y_scale)]
         [a-zp       (hip-extract-qdq-zeropoint-i64 %dq-a-op 0)]
         [y-zp       (hip-extract-qdq-zeropoint-i64 op 0)]
         [trans-a    (mlir-operation-get-integer-attr %mm-op "transA" 0)]
         [%init      (hip-build-init rewriter !y-type %matmul_init)])
    :rewrite %q :with
        (%result = (let ([new-op (mlir-build-operation "hip.qmatmul"
                                   (list %ctx %a %b %b_scales %b_zps %init)
                                   (list !y-type))])
                     (mlir-operation-set-f32-attr! new-op "A_scale"       a-scale)
                     (mlir-operation-set-i64-attr! new-op "A_zero_point"  a-zp)
                     (mlir-operation-set-f32-attr! new-op "Y_scale"       y-scale)
                     (mlir-operation-set-i64-attr! new-op "Y_zero_point"  y-zp)
                     (mlir-operation-set-i64-attr! new-op "transA"        trans-a)
                     (mlir-operation-set-i64-attr! new-op "transB"        0)
                     (mlir-operation-set-i64-attr! new-op "B_quant_axis"  1)
                     (mlir-operation-set-unit-attr! new-op "packed_int4")
                     (mlir-operation-get-result new-op 0))))

  ;;===--------------------------------------------------------------------===;;
  ;; Pattern 5: QMatMul per-column W8  (benefit 9)
  ;;===--------------------------------------------------------------------===;;

  (define-rewrite-pattern (hip-qmatmul-per-col-w8 op rewriter)
    :if-match
        %q      = hip.quantize_linear   (%ctx %matmul %y_scale)
                    :where (and (hip-splat-scale? %y_scale)
                                (hip-qdq-quantized-width? op '(8 16))
                                (hip-extractable-qdq-zeropoint? op))
        %matmul = hip.matmul            (%ctx %dq_a %dq_b %matmul_init)
                    :where (and (hip-value-single-use? %matmul)
                                (hip-can-build-init? op %matmul_init)
                                (num= (mlir-operation-get-integer-attr
                                        (mlir-value-get-defining-op %matmul) "transB" 0)
                                      0))
        %dq_a   = hip.dequantize_linear (%ctx %a %a_scale)
                    :where (and (hip-qdq-quantized-width?
                                  (mlir-value-get-defining-op %dq_a) '(8 16))
                                (hip-splat-scale? %a_scale)
                                (hip-extractable-qdq-zeropoint?
                                  (mlir-value-get-defining-op %dq_a)))
        %dq_b   = hip.dequantize_linear (%ctx %b %b_scales %b_zps %b_init)
                    :where (hip-per-axis-weight?
                              (mlir-value-get-defining-op %dq_b) 2 1 #f)
    :then-let
        ([!y-type    (mlir-value-get-type %q)]
         [%dq-a-op   (mlir-value-get-defining-op %dq_a)]
         [%mm-op     (mlir-value-get-defining-op %matmul)]
         [a-scale    (hip-extract-splat-scale %a_scale)]
         [y-scale    (hip-extract-splat-scale %y_scale)]
         [a-zp       (hip-extract-qdq-zeropoint-i64 %dq-a-op 0)]
         [y-zp       (hip-extract-qdq-zeropoint-i64 op 0)]
         [trans-a    (mlir-operation-get-integer-attr %mm-op "transA" 0)]
         [%init      (hip-build-init rewriter !y-type %matmul_init)])
    :rewrite %q :with
        (%result = (let ([new-op (mlir-build-operation "hip.qmatmul"
                                   (list %ctx %a %b %b_scales %b_zps %init)
                                   (list !y-type))])
                     (mlir-operation-set-f32-attr! new-op "A_scale"       a-scale)
                     (mlir-operation-set-i64-attr! new-op "A_zero_point"  a-zp)
                     (mlir-operation-set-f32-attr! new-op "Y_scale"       y-scale)
                     (mlir-operation-set-i64-attr! new-op "Y_zero_point"  y-zp)
                     (mlir-operation-set-i64-attr! new-op "transA"        trans-a)
                     (mlir-operation-set-i64-attr! new-op "transB"        0)
                     (mlir-operation-set-i64-attr! new-op "B_quant_axis"  1)
                     (mlir-operation-get-result new-op 0))))

) ;; end library (passes hip-fusion qmatmul)

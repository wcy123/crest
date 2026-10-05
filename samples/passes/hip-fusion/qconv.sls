#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (passes hip-fusion qconv) — Pattern 10: QConv  (benefit 10)
;; W4A16 unsigned, 1×1, per-output-channel weights
;; dq(activation) + dq(weights) → hip.conv → hip.quantize_linear  ⟹  hip.qconv
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion qconv)
  (export hip-qconv-fusion)

  (import (except (rnrs) =)
          (only (chezscheme) nan?)
          (rename (only (rnrs) =) (= num=))

          (only (mlir ir value)
                mlir::Value::getDefiningOp
                mlir::Value::getType)
          (only (mlir core builder) crest::RewriterBase::build)
          (mlir transforms dialect-conversion)
          (passes hip-fusion fusion)
          (crest)
          (passes hip-fusion helpers)
          (only (mlir ir operation)
                crest::Operation::setF32Attr crest::Operation::setI64Attr crest::Operation::setUnitAttr mlir::Operation::getResult)
  )

  (define-rewrite-pattern (hip-qconv-fusion op rewriter)
    :if-match
        %q    = hip.quantize_linear   (%ctx %conv %out_scale)
                  :where (and (hip-splat-scale? %out_scale)
                              (hip-qdq-quantized-width? op '(16))
                              (hip-qdq-unsigned? op)
                              (hip-extractable-qdq-zeropoint? op))
        %conv = hip.conv              (%ctx %dq_in %dq_w %conv_init)
                  :where (and (hip-value-single-use? %conv)
                              (hip-fusable-conv-geometry?
                                (mlir::Value::getDefiningOp %conv))
                              (hip-can-build-init? op %conv_init))
        %dq_in = hip.dequantize_linear (%ctx %input %in_scale)
                  :where (and (hip-qdq-quantized-width?
                                (mlir::Value::getDefiningOp %dq_in) '(16))
                              (hip-qdq-unsigned? (mlir::Value::getDefiningOp %dq_in))
                              (hip-splat-scale? %in_scale)
                              (hip-extractable-qdq-zeropoint?
                                (mlir::Value::getDefiningOp %dq_in)))
        %dq_w  = hip.dequantize_linear (%ctx %weights %w_scales %w_zps %w_init)
                  :where (hip-per-axis-weight?
                            (mlir::Value::getDefiningOp %dq_w) 4 0 #t)
    :then-let
        ([!out-type (mlir::Value::getType %q)]
         [%dq-in-op (mlir::Value::getDefiningOp %dq_in)]
         [in-scale  (hip-extract-splat-scale %in_scale)]
         [out-scale (hip-extract-splat-scale %out_scale)]
         [in-zp     (hip-extract-qdq-zeropoint-i64 %dq-in-op 0)]
         [out-zp    (hip-extract-qdq-zeropoint-i64 op 0)]
         [%init     (hip-build-init rewriter !out-type %conv_init)])
    :rewrite %q :with
        (%result = (let ([new-op (crest::RewriterBase::build "hip.qconv"
                                   (list %ctx %input %weights %w_scales %w_zps %init)
                                   (list !out-type))])
                     (crest::Operation::setF32Attr new-op "input_scale"   in-scale)
                     (crest::Operation::setI64Attr new-op "input_zp"      in-zp)
                     (crest::Operation::setF32Attr new-op "output_scale"  out-scale)
                     (crest::Operation::setI64Attr new-op "output_zp"     out-zp)
                     (crest::Operation::setI64Attr new-op "weight_axis"   0)
                     (mlir-operation-set-i64-array-attr! new-op "kernel_shape" '(1 1))
                     (mlir-operation-set-i64-array-attr! new-op "strides"      '(1 1))
                     (mlir-operation-set-i64-array-attr! new-op "pads"         '(0 0 0 0))
                     (mlir-operation-set-i64-array-attr! new-op "dilations"    '(1 1))
                     (crest::Operation::setI64Attr new-op "group"          1)
                     (crest::Operation::setUnitAttr new-op "packed_int4")
                     (mlir::Operation::getResult new-op 0))))

) ;; end library (passes hip-fusion qconv)

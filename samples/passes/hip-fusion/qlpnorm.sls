#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (passes hip-fusion qlpnorm) — Pattern 12: QLpNormalization  (benefit 10)
;; dq(input) → hip.rms_norm (L2-equivalent) → hip.quantize_linear
;;                                           ⟹  hip.qlpnormalization
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion qlpnorm)
  (export hip-qlpnorm-fusion)

  (import (except (rnrs) =)
          (only (chezscheme) nan?)
          (rename (only (rnrs) =) (= num=))

          (only (mlir IR Value)
                mlir::Value::getDefiningOp
                mlir::Value::getType)
          (only (mlir IR PatternMatch) mlir-create-operation)
          (mlir Transforms DialectConversion)
          (passes hip-fusion fusion)
          (crest)
          (passes hip-fusion helpers)
          (only (mlir IR Operation)
                crest::Operation::setI64Attr mlir::Operation::getResult)
          )

  (define-rewrite-pattern (hip-qlpnorm-fusion op rewriter)
    :if-match
      %q     = hip.quantize_linear   (%ctx %rms %out_scale)
        :where (and (hip-splat-scale? %out_scale)
                    (hip-qdq-quantized-width? op '(16))
                    (hip-qdq-unsigned? op)
                    (hip-extractable-qdq-zeropoint? op))
      %rms   = hip.rms_norm          (%ctx %dq_in %rms_scale %rms_init)
        :where (and (hip-value-single-use? %rms)
                    (hip-l2-equiv-rms-norm? (mlir::Value::getDefiningOp %rms))
                    (hip-can-build-init? op %rms_init))
      %dq_in = hip.dequantize_linear (%ctx %input %in_scale)
        :where (and (hip-qdq-quantized-width?
                     (mlir::Value::getDefiningOp %dq_in) '(16))
                    (hip-qdq-unsigned? (mlir::Value::getDefiningOp %dq_in))
                    (hip-splat-scale? %in_scale)
                    (hip-extractable-qdq-zeropoint?
                     (mlir::Value::getDefiningOp %dq_in)))
    :then-let
      ([!out-type (mlir::Value::getType %q)]
       [%dq-in-op (mlir::Value::getDefiningOp %dq_in)]
       [in-scale  (hip-extract-splat-scale %in_scale)]
       [out-scale (hip-extract-splat-scale %out_scale)]
       [in-zp     (hip-extract-qdq-zeropoint-i64 %dq-in-op 0)]
       [out-zp    (hip-extract-qdq-zeropoint-i64 op 0)]
       [%init     (hip-build-init rewriter !out-type %rms_init)])
    :rewrite %q :with
      (%result = (let ([new-op (mlir-create-operation rewriter "hip.qlpnormalization"
                                                      (list %ctx %input %init)
                                                      (list !out-type))])
                   (set-qdq-in-out-attrs! new-op in-scale in-zp out-scale out-zp)
                   (crest::Operation::setI64Attr new-op "axis" -1)
                   (crest::Operation::setI64Attr new-op "p"    2)
                   (mlir::Operation::getResult new-op 0))))

  ) ;; end library (passes hip-fusion qlpnorm)

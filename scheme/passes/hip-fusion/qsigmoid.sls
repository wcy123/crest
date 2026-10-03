#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (passes hip-fusion qsigmoid) — Pattern 11: QSigmoid  (benefit 10)
;; dq(input) → hip.sigmoid → hip.quantize_linear  ⟹  hip.qsigmoid
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion qsigmoid)
  (export hip-qsigmoid-fusion)

  (import (except (rnrs) =)
          (only (chezscheme) nan?)
          (rename (only (rnrs) =) (= num=))
          (mlir core ir)
          (mlir core conversion)
          (mlir hip fusion)
          (mlir ddr)
          (passes hip-fusion helpers))

  (define-rewrite-pattern (hip-qsigmoid-fusion op rewriter)
    :if-match
        %q       = hip.quantize_linear   (%ctx %sigmoid %out_scale)
                     :where (and (hip-splat-scale? %out_scale)
                                 (hip-qdq-quantized-width? op '(16))
                                 (hip-qdq-unsigned? op)
                                 (hip-extractable-qdq-zeropoint? op))
        %sigmoid = hip.sigmoid           (%ctx %dq_in %sigmoid_init)
                     :where (and (hip-value-single-use? %sigmoid)
                                 (hip-can-build-init? op %sigmoid_init))
        %dq_in   = hip.dequantize_linear (%ctx %input %in_scale)
                     :where (and (hip-qdq-quantized-width?
                                   (mlir-value-get-defining-op %dq_in) '(16))
                                 (hip-qdq-unsigned? (mlir-value-get-defining-op %dq_in))
                                 (hip-splat-scale? %in_scale)
                                 (hip-extractable-qdq-zeropoint?
                                   (mlir-value-get-defining-op %dq_in)))
    :then-let
        ([!out-type (mlir-value-get-type %q)]
         [%dq-in-op (mlir-value-get-defining-op %dq_in)]
         [in-scale  (hip-extract-splat-scale %in_scale)]
         [out-scale (hip-extract-splat-scale %out_scale)]
         [in-zp     (hip-extract-qdq-zeropoint-i64 %dq-in-op 0)]
         [out-zp    (hip-extract-qdq-zeropoint-i64 op 0)]
         [%init     (hip-build-init rewriter !out-type %sigmoid_init)])
    :rewrite %q :with
        (%result = (let ([new-op (mlir-build-operation "hip.qsigmoid"
                                   (list %ctx %input %init)
                                   (list !out-type))])
                     (set-qdq-in-out-attrs! new-op in-scale in-zp out-scale out-zp)
                     (mlir-operation-get-result new-op 0))))

) ;; end library (passes hip-fusion qsigmoid)

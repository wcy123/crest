#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (passes hip-fusion) — hip quantized-op fusion pass entry point.
;;
;; Aggregates all per-op pattern sub-libraries and registers them with the
;; greedy rewriter.  Each sub-library lives in scheme/passes/hip-fusion/:
;;
;;   helpers.sls       — shared attr-setters and FFI bindings
;;   qadd.sls          — Pattern  1: QAdd
;;   qmul.sls          — Pattern  2: QMul
;;   qmatmul.sls       — Patterns 3–5: QMatMul (per-tensor, per-col-W4/W8)
;;   qgemm.sls         — Patterns 6–9: QGemm (per-tensor ±bias, per-channel ±bias)
;;   qconv.sls         — Pattern 10: QConv
;;   qsigmoid.sls      — Pattern 11: QSigmoid
;;   qlpnorm.sls       — Pattern 12: QLpNormalization
;;   qdq-roundtrip.sls — Patterns 13–15: QdqRoundTrip (DPS, tensor, pair)
;;
;; Entry point: (pass-entry-point module-op)
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion)
  (export pass-entry-point)

  (import (except (rnrs) =)
          (rename (only (rnrs) =) (= num=))

          (crest)
          (passes hip-fusion helpers)
          (passes hip-fusion qadd)
          (passes hip-fusion qmul)
          (passes hip-fusion qmatmul)
          (passes hip-fusion qgemm)
          (passes hip-fusion qconv)
          (passes hip-fusion qsigmoid)
          (passes hip-fusion qlpnorm)
          (passes hip-fusion qdq-roundtrip)
          (only (mlir IR Operation)
                mlir::Operation::getContext)
          (only (mlir IR MLIRContext)
                with-current-MLIRContext)
          )

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-patterns module-op ctx
                        :patterns (("hip.quantize_linear" hip-qadd-fusion 10)
                                   ("hip.quantize_linear" hip-qmul-fusion 10)
                                   ("hip.quantize_linear" hip-qmatmul-fusion 10)
                                   ("hip.quantize_linear" hip-qmatmul-per-col-w4 9)
                                   ("hip.quantize_linear" hip-qmatmul-per-col-w8 9)
                                   ("hip.quantize_linear" hip-qgemm-fusion 10)
                                   ("hip.quantize_linear" hip-qgemm-no-bias 10)
                                   ("hip.quantize_linear" hip-qgemm-per-channel 9)
                                   ("hip.quantize_linear" hip-qgemm-no-bias-per-channel 9)
                                   ("hip.quantize_linear" hip-qconv-fusion 10)
                                   ("hip.quantize_linear" hip-qsigmoid-fusion 10)
                                   ("hip.quantize_linear" hip-qlpnorm-fusion 10)
                                   ("hip.quantize_linear" hip-qdq-roundtrip-dps 10)
                                   ("hip.quantize_linear" hip-qdq-roundtrip-tensor 10)
                                   ("hip.quantize_linear" hip-qdq-roundtrip-pair 10))))))

  ) ;; end library (passes hip-fusion)

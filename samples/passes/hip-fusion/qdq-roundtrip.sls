#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (passes hip-fusion qdq-roundtrip) — Patterns 13–15: Q/DQ round-trip elimination
;;
;;   Pattern 13: hip DPS layout op  Q(LAYOUT(%ctx, DQ(x))) → LAYOUT(x) (benefit 10)
;;   Pattern 14: tensor layout op   Q(LAYOUT(DQ(x)))       → LAYOUT(x) (benefit 10)
;;   Pattern 15: adjacent pair      Q(DQ(x))               → x         (benefit 10)
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion qdq-roundtrip)
  (export hip-qdq-roundtrip-dps
          hip-qdq-roundtrip-tensor
          hip-qdq-roundtrip-pair)

  (import (except (rnrs) =)
          (only (chezscheme) nan?)
          (rename (only (rnrs) =) (= num=))
          (mlir core ir)
          (mlir core conversion)
          (mlir hip fusion)
          (crest)
          (passes hip-fusion helpers))

  ;;===--------------------------------------------------------------------===;;
  ;; Pattern 13: QdqRoundTrip — hip DPS layout op  (benefit 10)
  ;; Q(LAYOUT_DPS(DQ(x))) → clone layout with quantized type
  ;; The :where is on %dq; at that point %layout IS bound (Q's operand 1)
  ;;===--------------------------------------------------------------------===;;

  (define-rewrite-pattern (hip-qdq-roundtrip-dps op rewriter)
    :if-match
        %q      = hip.quantize_linear   (%ctx %layout %out_scale)
        %layout = :any                  (%ctx %dq)
        %dq     = hip.dequantize_linear (%ctx %input %in_scale)
                    :where (and (hip-value-single-use? %layout)
                                (hip-matching-qdq-params?
                                  (mlir-value-get-defining-op %dq) op)
                                (hip-can-requantize-layout-op?
                                  (mlir-value-get-defining-op %layout) op))
    :then-let
        ([%dq-op     (mlir-value-get-defining-op %dq)]
         [%layout-op (mlir-value-get-defining-op %layout)])
    :rewrite %q :with
        (%result = (hip-create-requantized-layout-op rewriter %dq-op %layout-op op)))

  ;;===--------------------------------------------------------------------===;;
  ;; Pattern 14: QdqRoundTrip — tensor layout op (no ctx)  (benefit 10)
  ;;===--------------------------------------------------------------------===;;

  (define-rewrite-pattern (hip-qdq-roundtrip-tensor op rewriter)
    :if-match
        %q      = hip.quantize_linear   (%ctx %layout %out_scale)
        %layout = :any                  (%dq)
        %dq     = hip.dequantize_linear (%ctx %input %in_scale)
                    :where (and (hip-value-single-use? %layout)
                                (not (hip-layout-op-has-ctx?
                                       (mlir-value-get-defining-op %layout)))
                                (hip-matching-qdq-params?
                                  (mlir-value-get-defining-op %dq) op)
                                (hip-can-requantize-layout-op?
                                  (mlir-value-get-defining-op %layout) op))
    :then-let
        ([%dq-op     (mlir-value-get-defining-op %dq)]
         [%layout-op (mlir-value-get-defining-op %layout)])
    :rewrite %q :with
        (%result = (hip-create-requantized-layout-op rewriter %dq-op %layout-op op)))

  ;;===--------------------------------------------------------------------===;;
  ;; Pattern 15: QdqRoundTrip — adjacent pair  (benefit 10)
  ;; Q(DQ(x)) → x when params match and types are identical
  ;;===--------------------------------------------------------------------===;;

  (define-rewrite-pattern (hip-qdq-roundtrip-pair op rewriter)
    :if-match
        %q  = hip.quantize_linear   (%ctx %dq %out_scale)
        %dq = hip.dequantize_linear (%ctx %input %in_scale)
                :where (and (hip-matching-qdq-params?
                              (mlir-value-get-defining-op %dq) op)
                            (hip-identity-roundtrip?
                              (mlir-value-get-defining-op %dq) op))
    :rewrite %q :with
        (%result = (begin %input)))

) ;; end library (passes hip-fusion qdq-roundtrip)

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; onnx.Expand → hipsr.expand
;;
;; Creates a Barrier placeholder with ins=(input, shape) then hipsr.expand.
;; The placeholder must be Barrier because the shape is computed at runtime
;; from the shape operand (a host tensor).
;;
;;===----------------------------------------------------------------------===;;

(library (passes onnx-to-hipsr expand)
  (export populate-expand-patterns)
  (import (except (rnrs (6)) =)

          (only (mlir IR Value)
                mlir::Value::getDefiningOp
                mlir::Value::getType)
          (mlir Transforms DialectConversion)
          (mlir dialects hipsr)
          (mlir Dialect Tensor IR)
          (only (mlir IR BuiltinTypes)
                mlir::RankedTensorType::cloneWithEncoding)
          (mlir support logging)
          (crest)
          (only (mlir IR Operation)
                mlir::OpOperand::get mlir::Operation::getContext mlir::Operation::getName)

          (only (mlir support logging)
                crest::logging::info)
	  )

  ;; Unwrap one level of builtin.unrealized_conversion_cast.
  ;; The type converter may wrap tensor<Nxi64> → device space; this removes
  ;; that wrapper to recover the host-space value that hipsr.placeholder requires.
  ;; Assumption: at most one cast is inserted. Nested casts are not handled.
  (define (unwrap-cast v)
    (let ([def (mlir::Value::getDefiningOp v)])
      (if (and (not (zero? def))
               (string=? (mlir::Operation::getName def)
                         "builtin.unrealized_conversion_cast"))
          (mlir::OpOperand::get def 0)
          v)))

  (define-conversion-pattern (onnx-expand->hipsr op operands-ref rewriter type-converter)
    :if-match
    %output = onnx.Expand (%input %shape-operand)
    :then-let
    ([ctx         (mlir::Operation::getContext op)]
     [%ctx        (mlir-get-hipsr-context-arg op)]
     [!out-type   (mlir::Value::getType %output)]
     [!out-device (mlir::RankedTensorType::cloneWithEncoding !out-type
							     (make-hipsr-device-space-attr))]
     [%shape-host (unwrap-cast %shape-operand)])
    ;; TODO: validate that %shape-host is host-space after unwrapping.
    ;; If unwrap-cast returns the original value unchanged and it is already
    ;; device-space, hipsr.placeholder (barrier) will receive a device tensor
    ;; which may fault at runtime. The C++ ExpandConversion.cpp validates rank,
    ;; element type, and static shape length — these checks are missing here.
    :rewrite %output :with
    (%placeholder = hipsr.placeholder (%ctx %input %shape-host)
                  ("placeholder_type" = (make-hipsr-barrier-type-attr))
                  -> !out-device)
    (%result = hipsr.expand (%ctx %input %shape-host %placeholder)
             -> !out-device))

  (define (populate-expand-patterns type-converter patterns ctx)
    (crest::logging::info "Registering onnx.Expand pattern")
    (add-conversion-pattern patterns "onnx.Expand"
                            onnx-expand->hipsr type-converter 1))

  ) ;; end library (onnx-to-hipsr expand)

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; onnx.Cast → hipsr.cast
;;
;;===----------------------------------------------------------------------===;;

(library (passes onnx-to-hipsr cast)
  (export populate-cast-patterns)
  (import (except (rnrs (6)) =)


          (mlir Transforms DialectConversion)
          (mlir dialects hipsr)
          (mlir Dialect Tensor IR)
          (only (mlir IR BuiltinTypes)
                mlir::RankedTensorType::cloneWithEncoding)
          (only (mlir Dialect Shape IR Shape)
                mlir::shape::ShapeType::get
                mlir::shape::SizeType::get
                mlir::shape::WitnessType::get)
          (crest)
          (only (mlir IR Operation)
                mlir::Operation::getContext)
          (only (mlir IR Value)
                mlir::Value::getType)
  )

  (define-conversion-pattern (onnx-cast->hipsr op operands-ref rewriter type-converter)
    :if-match
        %output = onnx.Cast (%input)
    :then-let
        ([ctx            (mlir::Operation::getContext op)]
         [%ctx           (mlir-get-hipsr-context-arg op)]
         [!output-type   (mlir::Value::getType %output)]
         [!output-device (mlir::RankedTensorType::cloneWithEncoding !output-type
                            (make-hipsr-device-space-attr))]
         [!shape-type    (mlir::shape::ShapeType::get)])
    :rewrite %output :with
        (%placeholder = hipsr.placeholder (%ctx %input)
                        (^bb0 ((%shape-in : !shape-type))
                              (hipsr.shape_yield (%shape-in)))
                        -> !output-device)
        (%cast = hipsr.cast (%ctx %input %placeholder)
                 -> !output-device))

  (define (populate-cast-patterns type-converter patterns ctx)
    (add-conversion-pattern patterns "onnx.Cast" onnx-cast->hipsr type-converter 1))

) ;; end library (onnx-to-hipsr cast)

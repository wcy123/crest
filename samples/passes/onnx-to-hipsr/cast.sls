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


          (mlir transforms dialect-conversion)
          (mlir dialects hipsr)
          (mlir dialect tensor ir)
          (only (mlir dialect shape ir)
                mlir::shape::ShapeType::get
                mlir::shape::SizeType::get
                mlir::shape::WitnessType::get)
          (crest)
          (only (mlir ir operation)
                mlir::Operation::getContext)
          (only (mlir ir value)
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
                            (make-hipsr-device-space-attr ctx))]
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

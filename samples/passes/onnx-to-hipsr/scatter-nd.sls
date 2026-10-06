#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; onnx.ScatterND → hipsr.scatter_nd
;;
;; Output shape = data shape (identity: scatter writes into a copy of data).
;;
;;===----------------------------------------------------------------------===;;

(library (passes onnx-to-hipsr scatter-nd)
  (export populate-scatter-nd-patterns
          onnx-scatter-nd->hipsr)
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
          (only (mlir IR Value)
                mlir::Value::getType)
  )

  (define-conversion-pattern (onnx-scatter-nd->hipsr op operands-ref rewriter type-converter)
    :if-match
        %output = onnx.ScatterND (%data %indices %updates)
    :then-let
        ([%ctx           (mlir-get-hipsr-context-arg op)]
         [!output-type   (mlir::Value::getType %output)]
         [!output-device (mlir::RankedTensorType::cloneWithEncoding !output-type (make-hipsr-device-space-attr))]
         [!shape-type    (mlir::shape::ShapeType::get)])
    :rewrite %output :with
        ;; placeholder ins = (%data) only: scatter output has data's shape
        (%placeholder = hipsr.placeholder (%ctx %data !output-device)
                        (^bb0 ((%data-shape : !shape-type))
                              (hipsr.shape_yield (%data-shape)))
                        -> !output-device)
        (%result = hipsr.scatter_nd (%ctx %data %indices %updates %placeholder)
                   -> !output-device))

  (define (populate-scatter-nd-patterns type-converter patterns ctx)
    (add-conversion-pattern patterns "onnx.ScatterND"
                                      onnx-scatter-nd->hipsr type-converter 1))

) ;; end library (onnx-to-hipsr scatter-nd)

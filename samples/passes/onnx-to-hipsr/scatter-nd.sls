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


          (mlir transforms dialect-conversion)
          (mlir dialects hipsr)
          (mlir dialects tensor)
          (only (mlir dialect shape)
                mlir::shape::ShapeType::get
                mlir::shape::SizeType::get
                mlir::shape::WitnessType::get)
          (crest)
          (only (mlir ir operation)
                mlir::Operation::getContext)

          (only (mlir ir value)
                mlir::Value::getType)

          (only (mlir ir type) mlir::Type::getContext)
  )

  (define-conversion-pattern (onnx-scatter-nd->hipsr op operands-ref rewriter type-converter)
    :if-match
        %output = onnx.ScatterND (%data %indices %updates)
    :then-let
        ([%ctx           (mlir-get-hipsr-context-arg op)]
         [!output-type   (mlir::Value::getType %output)]
         [!output-device (mlir-ranked-tensor-type-with-encoding !output-type (make-hipsr-device-space-attr (mlir::Type::getContext !output-type)))]
         [!shape-type    (mlir::shape::ShapeType::get (mlir::Operation::getContext op))])
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

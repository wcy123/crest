#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; onnx.Equal → hipsr.equal
;;
;; Output shape = broadcast(lhs_shape, rhs_shape).
;;
;;===----------------------------------------------------------------------===;;

(library (passes onnx-to-hipsr equal)
  (export populate-equal-patterns)
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

  (define-conversion-pattern (onnx-equal->hipsr op operands-ref rewriter type-converter)
    :if-match
      %output = onnx.Equal (%lhs %rhs)
    :then-let
      ([ctx            (mlir::Operation::getContext op)]
       [%ctx           (mlir-get-hipsr-context-arg op)]
       [!output-type   (mlir::Value::getType %output)]
       [!output-device (mlir::RankedTensorType::cloneWithEncoding !output-type
								  (make-hipsr-device-space-attr))]
       [!shape-type    (mlir::shape::ShapeType::get)])
    :rewrite %output :with
      (%placeholder = hipsr.placeholder (%ctx %lhs %rhs)
                    (^bb0 ((%lhs-shape : !shape-type) (%rhs-shape : !shape-type))
			  (%bcast = shape.broadcast (%lhs-shape %rhs-shape) -> !shape-type)
			  (hipsr.shape_yield (%bcast)))
                    -> !output-device)
      (%result = hipsr.equal (%ctx %lhs %rhs %placeholder)
               -> !output-device))

  (define (populate-equal-patterns type-converter patterns ctx)
    (add-conversion-pattern patterns "onnx.Equal"
                            onnx-equal->hipsr type-converter 1))

  ) ;; end library (onnx-to-hipsr equal)

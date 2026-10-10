#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; onnx.Gather → hipsr.gather  (device data path)
;;
;; DSL pattern: placeholder with inline shape region + hipsr.gather{axis}.
;; Shape region: split data_shape at axis, concat with indices_shape.
;; A :scheme helper builds the split/concat chain using the fresh OpBuilder.
;;
;;===----------------------------------------------------------------------===;;

(library (passes onnx-to-hipsr gather)
  (export populate-gather-patterns)
  (import (except (rnrs (6)) =)

          (only (mlir IR Value)
                mlir::Value::getDefiningOp
                mlir::Value::getType)
          (only (mlir IR BuiltinAttributes) mlir::IntegerAttr::get<index>)
          (mlir Transforms DialectConversion)
          (mlir dialects hipsr)
          (mlir Dialect Tensor IR)
          (only (mlir Dialect Shape IR Shape)
                mlir::shape::ShapeType::get
                mlir::shape::SizeType::get
                mlir::shape::WitnessType::get)
          (crest internal rewrite)
          (crest)
          (only (mlir IR Operation)
                mlir::Operation::emitRemark mlir::Operation::getAttrOfType<IntegerAttr> mlir::Operation::setAttr!)

          (only (mlir IR BuiltinTypes)
                mlir::RankedTensorType::cloneWithEncoding
                mlir::RankedTensorType::getRank))

  ;; Build the gather output shape inside a region block using the DSL.
  ;; Shape logic:
  ;;   leading, _ = split_at(data_shape, axis)
  ;;   _, trailing = split_at(data_shape, axis+1)
  ;;   result = concat(concat(leading, indices_shape), trailing)
  ;; Build the gather output shape inside a region block.
  ;; Shape logic:
  ;;   leading, _ = split_at(data_shape, axis)
  ;;   _, trailing = split_at(data_shape, axis+1)
  ;;   result = concat(concat(leading, indices_shape), trailing)
  ;; Build the gather output shape inside a region block.
  ;; Shape logic:
  ;;   leading, _ = split_at(data_shape, axis)
  ;;   _, trailing = split_at(data_shape, axis+1)
  ;;   result = concat(concat(leading, indices_shape), trailing)
  (define (build-gather-shape! builder axis data-shape idx-shape shape-type size-type)
    (begin-mlir-code builder
                     (%sz1              = shape.const_size ()
                                        ("value" = (mlir::IntegerAttr::get<index> axis))
                                        -> size-type)
                     ((%leading %_sp1)  = shape.split_at (data-shape %sz1)       -> (shape-type shape-type))
                     (%sz2              = shape.const_size ()
                                        ("value" = (mlir::IntegerAttr::get<index> (+ axis 1)))
                                        -> size-type)
                     ((%_sp2 %trailing) = shape.split_at (data-shape %sz2)       -> (shape-type shape-type))
                     (%gathered         = shape.concat   (%leading idx-shape)     -> shape-type)
                     (%result           = shape.concat   (%gathered %trailing)    -> shape-type)))

  (define-conversion-pattern (onnx-gather->hipsr op operands-ref rewriter type-converter)
    :if-match
      %output = onnx.Gather (%data %indices)
    :then-let
      ([%ctx        (mlir-get-hipsr-context-arg op)]
       [!data-type  (mlir::Value::getType %data)]
       [!out-type   (mlir::Value::getType %output)]
       [!out-device (mlir::RankedTensorType::cloneWithEncoding !out-type (make-hipsr-device-space-attr))]
       [!shape-type (mlir::shape::ShapeType::get)]
       [!size-type  (mlir::shape::SizeType::get)]
       [axis        (let ([a (mlir::Operation::getAttrOfType<IntegerAttr> op "axis" 0)])
                      (if (< a 0) (+ a (mlir::RankedTensorType::getRank !data-type)) a))]
       ;; guard: only handle device data (eqv? avoids shadowed = keyword)
       [ok?         (eqv? 1 (mlir-type-is-device-tensor !data-type))])
    :rewrite %output :with
      ;; Guard: device data only. Emit a remark so diagnostics are visible,
      ;; then return #f so the conversion framework falls through to the
      ;; fallback pattern (mlir-populate-gather-conversion-patterns).
      (_ = (if (not ok?)
               (begin (mlir::Operation::emitRemark op "onnx-gather->hipsr: skipping host data")
                      #f)
               #t))
      (%placeholder = "hipsr.placeholder" (%ctx %data %indices)
                    (^bb0 builder ((%ds : !shape-type) (%is : !shape-type))
                          (%result-shape = (build-gather-shape!
                                            builder axis %ds %is !shape-type !size-type))
                          ("hipsr.shape_yield" (%result-shape)))
                    -> !out-device)
      (%result = hipsr.gather (%ctx %data %indices %placeholder)
               (operandSegmentSizes = (list 1 1 1 1) :i32-array)
               ("axis" = axis :i64)
               -> !out-device))

  (define (populate-gather-patterns type-converter patterns ctx)
    (add-conversion-pattern patterns "onnx.Gather"
                            onnx-gather->hipsr type-converter 1))

  ) ;; end library (onnx-to-hipsr gather)

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; onnx.Transpose → hipsr.transpose
;;
;; DSL pattern: placeholder with inline shape region + hipsr.transpose.
;; The shape region permutes input extents according to the perm attribute
;; (absent perm = reverse permutation).
;; A :scheme helper builds the shape.const_size / shape.get_extent /
;; shape.from_extents chain inside the region using the fresh OpBuilder.
;;
;;===----------------------------------------------------------------------===;;

(library (passes onnx-to-hipsr transpose)
  (export populate-transpose-patterns)
  (import (except (rnrs (6)) =)

          (only (mlir IR Value)
                mlir::Value::getDefiningOp
                mlir::Value::getType)
          (only (mlir IR BuiltinAttributes)
                mlir::IntegerAttr::get<index>)
          (mlir Transforms DialectConversion)
          (mlir dialects hipsr)
          (mlir Dialect Tensor IR)
          (only (mlir Dialect Shape IR Shape)
                mlir::shape::ShapeType::get
                mlir::shape::SizeType::get
                mlir::shape::WitnessType::get)
          (crest)
          (only (mlir IR Operation)
                mlir::Operation::getResult mlir::Operation::setAttr! mlir::Operation::getAttr)
          (only (mlir IR BuiltinAttributes) mlir::DenseI64ArrayAttr::intoArrayRef)
          (only (mlir support array-ref) with-ArrayRef ArrayRef::at ArrayRef::size :i64)
          (rename (rime loop) (:with :rime-with))

          (only (mlir IR BuiltinTypes)
                mlir::RankedTensorType::cloneWithEncoding
                mlir::RankedTensorType::getRank))

  ;; Build the permuted output shape inside a region block.
  ;; Returns the output !shape.shape value.
  (define (build-permuted-shape! builder perm input-shape shape-type size-type)
    (let ([extents (map (lambda (p)
                          (begin-mlir-code (:builder builder)
                                           (%sz  = shape.const_size () ("value" = p :index) -> size-type)
                                           (%ext = shape.get_extent (input-shape %sz) -> size-type)))
                        perm)])
      (begin-mlir-code (:builder builder)
                       (%out = shape.from_extents (,@extents) -> shape-type))))

  (define-conversion-pattern (onnx-transpose->hipsr op operands-ref rewriter type-converter)
    :if-match
      %output = onnx.Transpose (%input)
    :then-let
      ([%ctx        (mlir-get-hipsr-context-arg op)]
       [!in-type    (mlir::Value::getType %input)]
       [!out-type   (mlir::Value::getType %output)]
       [!out-device (mlir::RankedTensorType::cloneWithEncoding !out-type (make-hipsr-device-space-attr))]
       [!shape-type (mlir::shape::ShapeType::get)]
       [!size-type  (mlir::shape::SizeType::get)]
       [perm        (let ([attr (mlir::Operation::getAttr op "perm")])
                      (if (zero? attr)
                          ;; absent perm → reverse permutation
                          (let ([rank (mlir::RankedTensorType::getRank !in-type)])
                            (let loop ([i 0] [acc '()])
                              (if (eqv? i rank) acc (loop (+ i 1) (cons i acc)))))
                          (with-ArrayRef (ref (mlir::DenseI64ArrayAttr::intoArrayRef attr))
                                         (loop :for i :from 0 :below (ArrayRef::size ref)
                                               :collect (ArrayRef::at ref i :i64)))))])
    :rewrite %output :with
      (%placeholder = "hipsr.placeholder" (%ctx %input !out-device)
                    (^bb0 ((%is : !shape-type))
                          (%out-shape = (build-permuted-shape!
                                         %block-builder perm %is !shape-type !size-type))
                          ("hipsr.shape_yield" (%out-shape)))
                    -> !out-device)
      (%result = hipsr.transpose (%ctx %input %placeholder !out-device)
               ("perm" = perm :i64-array)
               -> !out-device))

  (define (populate-transpose-patterns type-converter patterns ctx)
    (add-conversion-pattern patterns "onnx.Transpose"
                            onnx-transpose->hipsr type-converter 1))

  ) ;; end library (onnx-to-hipsr transpose)

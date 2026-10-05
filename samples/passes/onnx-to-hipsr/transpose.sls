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

          (only (mlir ir value)
                mlir::Value::getDefiningOp
                mlir::Value::getType)
          (only (mlir ir builtin-attributes ffi)
                %mlir::IntegerAttr::get<index>
                %mlir::DenseI64ArrayAttr::get)
          (only (mlir core builder) mlir-build-operation)
          (mlir transforms dialect-conversion)
          (mlir dialects hipsr)
          (mlir dialects tensor)
          (only (mlir dialect shape)
                mlir::shape::ShapeType::get
                mlir::shape::SizeType::get
                mlir::shape::WitnessType::get)
          (crest)
          (only (mlir ir operation)
                crest::Operation::getIntegerArrayAttr mlir::Operation::getContext mlir::Operation::getResult mlir::Operation::setAttr!)

          (only (mlir ir type) mlir::Type::getContext)

          (only (mlir ir builtin-types)
                mlir::RankedTensorType::getRank))

  ;; Build the permuted output shape inside a region block.
  ;; Uses mlir-build-operation — must be called inside with-current-block-builder.
  ;; Returns the output !shape.shape value.
  (define (build-permuted-shape! loc perm input-shape shape-type size-type)
    (let* ([extents
            (map (lambda (p)
                   (let* ([sz-op (mlir-build-operation "shape.const_size" '() (list size-type))])
                     (mlir::Operation::setAttr! sz-op "value" (%mlir::IntegerAttr::get<index> (mlir::Operation::getContext sz-op) p))
                     (let* ([ext-op (mlir-build-operation "shape.get_extent"
                                      (list input-shape
                                            (mlir::Operation::getResult sz-op 0))
                                      (list size-type))])
                       (mlir::Operation::getResult ext-op 0))))
                 perm)]
           [out-op (mlir-build-operation "shape.from_extents" extents (list shape-type))])
      (mlir::Operation::getResult out-op 0)))

  (define-conversion-pattern (onnx-transpose->hipsr op operands-ref rewriter type-converter)
    :if-match
        %output = onnx.Transpose (%input)
    :then-let
        ([%ctx        (mlir-get-hipsr-context-arg op)]
         [!in-type    (mlir::Value::getType %input)]
         [!out-type   (mlir::Value::getType %output)]
         [!out-device (mlir-ranked-tensor-type-with-encoding !out-type (make-hipsr-device-space-attr (mlir::Type::getContext !out-type)))]
         [!shape-type (mlir::shape::ShapeType::get (mlir::Operation::getContext op))]
         [!size-type  (mlir::shape::SizeType::get  (mlir::Operation::getContext op))]
         [perm        (let ([raw (crest::Operation::getIntegerArrayAttr op "perm")])
                        (if (null? raw)
                            ;; absent perm → reverse permutation
                            (let ([rank (mlir::RankedTensorType::getRank !in-type)])
                              (let loop ([i 0] [acc '()])
                                (if (eqv? i rank) acc (loop (+ i 1) (cons i acc)))))
                            raw))])
    :rewrite %output :with
        (%placeholder = "hipsr.placeholder" (%ctx %input !out-device)
                        (^bb0 ((%is : !shape-type))
                              (%out-shape = (build-permuted-shape!
                                              op perm %is !shape-type !size-type))
                              ("hipsr.shape_yield" (%out-shape)))
                        -> !out-device)
        ;; :scheme — create transpose op and set perm attribute via mlir-build-operation
        (%result = (let* ([new-op (mlir-build-operation "hipsr.transpose"
                                    (list %ctx %input %placeholder !out-device)
                                    (list !out-device))])
                     (mlir::Operation::setAttr! new-op "perm" (%mlir::DenseI64ArrayAttr::get (mlir::Operation::getContext new-op) perm))
                     (mlir::Operation::getResult new-op 0))))

  (define (populate-transpose-patterns type-converter patterns ctx)
    (add-conversion-pattern patterns "onnx.Transpose"
                                      onnx-transpose->hipsr type-converter 1))

) ;; end library (onnx-to-hipsr transpose)

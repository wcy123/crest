#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; onnx.Shape → hipsr.placeholder + hipsr.compute (host output)
;;
;; Extracts tensor dimension sizes [start, end) as i64 scalars.
;; Mirrors ShapeConversion.cpp: uses arith.constant (index) in the shape
;; region and tensor.insert in the compute body, with static-dim detection.
;;
;;===----------------------------------------------------------------------===;;

(library (passes onnx-to-hipsr shape)
  (export populate-shape-patterns
          onnx-shape->hipsr)
  (import (except (rnrs (6)) =)

          (only (mlir IR Value)
                mlir::Value::getDefiningOp
                mlir::Value::getType)
          (only (mlir IR BuiltinAttributes)
                mlir::IntegerAttr::get<index>
                mlir::IntegerAttr::get<i64>)
          (mlir Transforms DialectConversion)
          (mlir dialects hipsr)
          (only (mlir Dialect Shape IR Shape)
                mlir::shape::ShapeType::get
                mlir::shape::SizeType::get
                mlir::shape::WitnessType::get)
          (crest internal rewrite)
          (rename (rime loop) (:with :rime-with))
          (crest)
          (only (mlir IR Operation)
                mlir::Operation::getAttrOfType<IntegerAttr> mlir::Operation::getContext)

          (only (mlir IR BuiltinTypes)
                mlir::IndexType::get
                mlir::IntegerType::get<i64>
                mlir::RankedTensorType::getRank
                mlir::RankedTensorType::getShape))

  ;; MLIR uses kDynamic = std::numeric_limits<int64_t>::min() for unknown dims.
  (define (dynamic-dim? d) (< d 0))

  ;; Normalize an ONNX axis bound: add rank for negative, then clamp to [0, rank].
  ;; use-default? controls whether zero means "absent" (-> default-val).
  (define (normalize-bound raw rank use-default? default-val)
    (let* ([v (if (and use-default? (zero? raw)) default-val raw)]
           [v (if (< v 0) (+ v rank) v)])
      (max 0 (min rank v))))

  ;; Build the compute body: for each axis in [start, end), insert the extent
  ;; into the destination tensor via tensor.insert. Returns the final tensor Value*.
  ;; Mirrors ShapeConversion.cpp::populateComputeBody.
  (define (build-compute-body! builder in-val dest-val input-shape start end
                               index-type i64-type out-host-type)
    (loop :for axis :from start :below end
          :for slot :from 0
          :rime-with acc := dest-val
          :for dim :in (list-tail input-shape start)
          :rime-with acc := (if (dynamic-dim? dim)
                                (begin-mlir-code builder
                                                 (%ci     = arith.constant () ("value" = axis :index) -> index-type)
                                                 (%d      = tensor.dim (in-val %ci) -> index-type)
                                                 (%e      = arith.index_cast (%d) -> i64-type)
                                                 (%slot-c = arith.constant () ("value" = slot :index) -> index-type)
                                                 (%ins    = tensor.insert (%e acc %slot-c) -> out-host-type))
                                (begin-mlir-code builder
                                                 (%e      = arith.constant () ("value" = dim :i64) -> i64-type)
                                                 (%slot-c = arith.constant () ("value" = slot :index) -> index-type)
                                                 (%ins    = tensor.insert (%e acc %slot-c) -> out-host-type)))
          :finally acc))

  (define-conversion-pattern (onnx-shape->hipsr op operands-ref rewriter type-converter)
    :if-match
      %output = onnx.Shape (%input)
    :then-let
      ([ctx         (mlir::Operation::getContext op)]
       [!input-type (mlir::Value::getType %input)]
       [!out-type   (mlir::Value::getType %output)]
       [!out-host   (make-mlir-tensor-in-host-space !out-type)]
       [input-rank  (mlir::RankedTensorType::getRank !input-type)]
       [input-shape (mlir::RankedTensorType::getShape !input-type)]
       [%ctx        (mlir-get-hipsr-context-arg op)]
       [start-raw   (mlir::Operation::getAttrOfType<IntegerAttr> op "start" 0)]
       [end-raw     (mlir::Operation::getAttrOfType<IntegerAttr> op "end" 0)]
       ;; ONNX normalizes negative bounds by adding rank, then clamps to [0, rank].
       ;; A zero end means "absent" and defaults to the rank.
       [start       (normalize-bound start-raw input-rank #f 0)]
       [end         (normalize-bound end-raw   input-rank #t  input-rank)]
       [num-dims    (- end start)]
       [!shape-type (mlir::shape::ShapeType::get)]
       [!index-type (mlir::IndexType::get       ctx)]
       [!i64-type   (mlir::IntegerType::get<i64>         ctx)]
       [!ctx-type   (mlir-get-hipsr-context-type ctx)])
    :rewrite %output :with
      ;; Placeholder: shape region yields const shape [num-dims].
      ;; Uses arith.constant (index) → shape.from_extents, matching
      ;; ShapeConversion.cpp::populateShapeRegion.
      (%placeholder = hipsr.placeholder (%ctx %input !out-host)
                    (^bb0 ((%s : !shape-type))
                          (%cN = arith.constant () (value = num-dims :index) -> !index-type)
                          (%r  = shape.from_extents (%cN) -> !shape-type)
                          (hipsr.shape_yield (%r)))
                    -> !out-host)
      ;; Compute body: inserts extents one by one via tensor.insert.
      ;; build-compute-body! uses mlir-create-operation directly to mix
      ;; Scheme control flow with MLIR op creation.
      (%result = hipsr.compute (%ctx %input %placeholder !out-host)
               (operandSegmentSizes = (list 1 1 1) :i32-array)
               (^bb0 ((%c : !ctx-type) (%in : !input-type) (%dest : !out-host))
                     (%final = (build-compute-body!
                                %block-builder %in %dest input-shape start end
                                !index-type !i64-type !out-host))
                     (hipsr.compute_yield (%final)))
               -> !out-host))

  (define (populate-shape-patterns type-converter patterns ctx)
    (add-conversion-pattern patterns "onnx.Shape"
                            onnx-shape->hipsr type-converter 1))

  ) ;; end library (onnx-to-hipsr shape)

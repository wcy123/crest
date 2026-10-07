#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest util) — CREST-specific conversion helpers.
;;
;; High-level conveniences for common dialect-conversion patterns.  These are
;; CREST policy, not mirrors of any MLIR header; implemented entirely in
;; Scheme using the generic C bindings.
;;
;;===----------------------------------------------------------------------===;;

(library (crest util)
  (export
    add-tensor-cast-materialization)

  (import (rnrs)
          (only (mlir IR BuiltinTypes)
                mlir::isa<RankedTensorType>?)
          (only (mlir IR Value)
                mlir::Value::getType)
          (only (mlir Dialect Tensor IR)
                mlir::tensor::CastOp::areCastCompatible
                mlir::tensor::CastOp::create)
          (only (mlir Transforms DialectConversion)
                type-converter-add-source-materialization
                type-converter-add-target-materialization))

  ;; @brief add-tensor-cast-materialization
  ;;        Register source and target materializations that insert a
  ;;        tensor.cast whenever a ranked tensor can be widened to the
  ;;        requested result type (i.e. mlir::tensor::CastOp::areCastCompatible
  ;;        returns true).  Both materializations use the same callback so
  ;;        widening works in both directions of the type-conversion pipeline.
  ;;
  ;; @param converter  TypeConverter* uptr
  (define (add-tensor-cast-materialization converter)
    (define (widen builder result-type inputs loc)
      (if (not (and (pair? inputs) (null? (cdr inputs))))
          #f
          (let* ([input      (car inputs)]
                 [input-type (mlir::Value::getType input)])
            (if (not (and (mlir::isa<RankedTensorType>? input-type)
                          (mlir::isa<RankedTensorType>? result-type)
                          (= 1 (mlir::tensor::CastOp::areCastCompatible
                                input-type result-type))))
                #f
                (mlir::tensor::CastOp::create builder loc result-type input)))))
    (type-converter-add-source-materialization converter widen)
    (type-converter-add-target-materialization converter widen))

  ) ;; end library (crest util)

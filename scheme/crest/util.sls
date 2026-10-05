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
;; CREST policy, not mirrors of mlir/Transforms/DialectConversion.h; they are
;; implemented entirely in Scheme using the generic C bindings.
;;
;;===----------------------------------------------------------------------===;;

(library (crest util)

  (export
    conversion-target-add-common-legal-ops
    conversion-target-add-dynamically-legal-func
    type-converter-add-tensor-widening-materialization)

  (import (rnrs)
          (only (mlir ir mlir-context) current-mlir-context)
          (only (mlir ir builtin-types)
                mlir::isa<RankedTensorType>?)
          (only (mlir ir value) mlir::Value::getType)
          (only (mlir dialect tensor ir)
                mlir::tensor::CastOp::areCastCompatible
                mlir::tensor::CastOp::create)
          (mlir transforms dialect-conversion))

  ;; @brief Mark builtin.module and arith.constant as unconditionally legal.
  ;;
  ;; These ops are present in every module and are typically not subject to
  ;; conversion.  Replaces the removed C helper
  ;; mlir_transforms_dialect_conversion_target_add_legal_common_ops.
  ;;
  ;; @param target  ConversionTarget* uptr
  (define (conversion-target-add-common-legal-ops target)
    (let ((ctx (current-mlir-context)))
      (target-add-legal-op target ctx "builtin.module")
      (target-add-legal-op target ctx "arith.constant")))

  ;; @brief Mark func.func and func.return as dynamically legal via a
  ;;        TypeConverter.
  ;;
  ;; func.func is legal when the converter considers the function's signature
  ;; legal (type-converter-is-signature-legal); func.return is legal when all
  ;; its operand types are legal (type-converter-is-legal).
  ;; Replaces the removed C helper
  ;; mlir_transforms_dialect_conversion_target_add_dynamically_legal_func.
  ;;
  ;; @param target    ConversionTarget* uptr
  ;; @param converter TypeConverter* uptr
  (define (conversion-target-add-dynamically-legal-func target converter)
    (let ((ctx (current-mlir-context)))
      (target-add-dynamically-legal-op target ctx "func.func"
        (lambda (op)
          (= 1 (type-converter-is-signature-legal converter op))))
      (target-add-dynamically-legal-op target ctx "func.return"
        (lambda (op)
          (= 1 (type-converter-is-legal converter op))))))

  ;; @brief Register source and target tensor-widening materializations.
  ;;
  ;; Inserts a tensor.cast to bridge unrealized_conversion_cast between
  ;; compatible ranked tensor types (e.g. tensor<?x32xf16,dev> →
  ;; tensor<?x?xf16,dev>).  Required when a conversion pattern produces a more
  ;; specific type than the TypeConverter declares for the result.
  ;;
  ;; Replaces the removed C helper
  ;; mlir_transforms_dialect_conversion_type_converter_add_tensor_widening_materialization.
  ;;
  ;; @param converter TypeConverter* uptr
  (define (type-converter-add-tensor-widening-materialization converter)
    (define (widen-materialize builder result-type inputs loc)
      ;; inputs is a Scheme list of Value uptrs; only handle the single-input case.
      (if (not (and (pair? inputs) (null? (cdr inputs))))
          #f
          (let* ((input       (car inputs))
                 (input-type  (mlir::Value::getType input)))
            (if (not (and (mlir::isa<RankedTensorType>? input-type)
                          (mlir::isa<RankedTensorType>? result-type)
                          (= 1 (mlir::tensor::CastOp::areCastCompatible
                                input-type result-type))))
                #f
                (mlir::tensor::CastOp::create builder loc result-type input)))))
    (type-converter-add-source-materialization converter widen-materialize)
    (type-converter-add-target-materialization converter widen-materialize))

) ;; end library (crest util)

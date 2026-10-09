#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Transforms DialectConversion) — MLIR Dialect Conversion Framework.
;;
;; Mirrors mlir/Transforms/DialectConversion.h: TypeConverter, ConversionTarget,
;; RewritePatternSet, applyFullConversion, and Scheme-pattern registration.
;;
;; Raw C bindings with % prefix live in (mlir Transforms DialectConversion ffi).
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Transforms DialectConversion)

  (export
    type-converter-create
    type-converter-add-conversion
    mlir::TypeConverter::addSourceMaterialization
    mlir::TypeConverter::addTargetMaterialization
    type-converter-is-legal-type
    type-converter-is-legal
    type-converter-is-signature-legal
    target-create
    target-add-illegal-dialect
    target-add-legal-dialect
    target-add-legal-op
    target-add-dynamically-legal-op
    target-mark-unknown-ops-dynamically-legal
    pattern-set-create
    apply-full-conversion
    add-conversion-pattern
    add-rewrite-pattern
    populate-func-type-conversion
    crest::isa<CrestOwned<mlir::TypeConverter>>?
    crest::isa<CrestOwned<mlir::ConversionTarget>>?
    with-TypeConverter
    with-ConversionTarget
    )

  (import (rnrs)
          (mlir Transforms DialectConversion ffi)
          (only (mlir IR PatternMatch)
                mlir::RewritePatternSet::RewritePatternSet)
          (only (mlir support array-ref) with-CrestObject)
          (only (mlir IR MLIRContext) current-MLIRContext))

  ;; @brief mlir::TypeConverter constructor — allocate a new TypeConverter.
  ;; @return CrestOwned<TypeConverter>* uptr — freed via with-CrestObject
  (define type-converter-create
    %type-converter-create)

  ;; @brief TypeConverter::addConversion — register a Scheme type-conversion callback.
  (define type-converter-add-conversion
    %type-converter-add-conversion)

  ;; @brief TypeConverter::addSourceMaterialization.
  (define mlir::TypeConverter::addSourceMaterialization
    %mlir::TypeConverter::addSourceMaterialization)

  ;; @brief TypeConverter::addTargetMaterialization.
  (define mlir::TypeConverter::addTargetMaterialization
    %mlir::TypeConverter::addTargetMaterialization)

  ;; @brief TypeConverter::isLegal(Type).
  (define type-converter-is-legal-type
    %type-converter-is-legal-type)

  ;; @brief TypeConverter::isLegal(Operation*).
  (define type-converter-is-legal
    %type-converter-is-legal)

  ;; @brief TypeConverter::isSignatureLegal.
  (define type-converter-is-signature-legal
    %type-converter-is-signature-legal)

  ;; @brief mlir::ConversionTarget constructor.
  ;; @param ctx MLIRContext* uptr
  ;; @return    CrestOwned<ConversionTarget>* uptr — freed via with-CrestObject
  (define target-create
    %target-create)

  ;; @brief ConversionTarget::addIllegalDialect.
  (define target-add-illegal-dialect
    %target-add-illegal-dialect)

  ;; @brief ConversionTarget::addLegalDialect.
  (define target-add-legal-dialect
    %target-add-legal-dialect)

  ;; @brief ConversionTarget::addLegalOp.
  (define target-add-legal-op
    %target-add-legal-op)

  ;; @brief ConversionTarget::addDynamicallyLegalOp.
  (define target-add-dynamically-legal-op
    %target-add-dynamically-legal-op)

  ;; @brief ConversionTarget::markUnknownOpDynamicallyLegal.
  (define target-mark-unknown-ops-dynamically-legal
    %target-mark-unknown-ops-dynamically-legal)

  ;; @brief mlir::RewritePatternSet constructor.
  ;; @param ctx MLIRContext* uptr
  ;; @return    CrestOwned<RewritePatternSet>* uptr — freed via with-CrestObject
  (define pattern-set-create
    mlir::RewritePatternSet::RewritePatternSet)

  ;; @brief mlir::applyFullConversion.
  (define apply-full-conversion
    %apply-full-conversion)

  ;; @brief Register a Scheme ConversionPattern.
  (define add-conversion-pattern
    %add-conversion-pattern)

  ;; @brief Register a Scheme RewritePattern (no TypeConverter).
  (define add-rewrite-pattern
    %add-rewrite-pattern)

  ;; @brief mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>.
  (define populate-func-type-conversion
    %populate-func-type-conversion)

  ;; @brief crest::isa<CrestOwned<mlir::TypeConverter>>? — is this ptr a CrestOwned<mlir::TypeConverter>?
  (define (crest::isa<CrestOwned<mlir::TypeConverter>>? ptr)
    (not (zero? (%crest::isa<CrestOwned<mlir::TypeConverter>> ptr))))

  ;; @brief crest::isa<CrestOwned<mlir::ConversionTarget>>? — is this ptr a CrestOwned<mlir::ConversionTarget>?
  (define (crest::isa<CrestOwned<mlir::ConversionTarget>>? ptr)
    (not (zero? (%crest::isa<CrestOwned<mlir::ConversionTarget>> ptr))))

  ;; @brief RAII macro — create a TypeConverter, execute BODY, then destroy on exit.
  ;; @param var  identifier bound to the CrestOwned<TypeConverter>* uptr for BODY
  ;; @example
  ;;   (with-TypeConverter (tc)
  ;;     (type-converter-add-conversion tc my-fn)
  ;;     ...)
  (define-syntax with-TypeConverter
    (syntax-rules ()
      [(_ (var) body ...)
       (with-CrestObject (var (type-converter-create))
                         body ...)]))

  ;; @brief RAII macro — create a ConversionTarget, execute BODY, then destroy on exit.
  ;; @param var identifier bound to the CrestOwned<ConversionTarget>* uptr for BODY
  ;; @param ctx MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @example
  ;;   (with-ConversionTarget (tgt)
  ;;     (target-add-illegal-dialect tgt "onnx")
  ;;     ...)
  (define-syntax with-ConversionTarget
    (syntax-rules ()
      [(_ (var) body ...)
       (with-CrestObject (var (target-create (current-MLIRContext)))
                         body ...)]
      [(_ (var ctx) body ...)
       (with-CrestObject (var (target-create ctx))
                         body ...)]))

  ) ;; end library (mlir Transforms DialectConversion)

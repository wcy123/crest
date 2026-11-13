#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Transforms DialectConversion ffi) — Raw C bindings.
;;
;; All names carry a % prefix to signal "raw C binding". Users import
;; (mlir Transforms DialectConversion) for clean names.
;;
;; Mirrors mlir/Transforms/DialectConversion.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Transforms DialectConversion ffi)

  (export
    %type-converter-create
    %type-converter-add-conversion
    %mlir::TypeConverter::addSourceMaterialization
    %mlir::TypeConverter::addTargetMaterialization
    %type-converter-is-legal-type
    %type-converter-is-legal
    %type-converter-is-signature-legal
    %target-create
    %target-add-illegal-dialect
    %target-add-legal-dialect
    %target-add-legal-op
    %target-add-dynamically-legal-op
    %target-mark-unknown-ops-dynamically-legal
    %apply-full-conversion
    %add-conversion-pattern
    %add-conversion-pattern/ctx
    %add-rewrite-pattern
    %populate-func-type-conversion
    %crest::isa<CrestBox<mlir::TypeConverter>>
    %crest::isa<CrestBox<mlir::ConversionTarget>>
    %mlir::applyPartialConversion
    %mlir::RewriterBase::modifyOpInPlace)

  (import (chezscheme)
          (mlir support foreign))

  ;; @brief mlir::TypeConverter constructor — allocate a new CrestBox<TypeConverter>.
  ;; @return CrestBox<TypeConverter>* uptr — freed via with-CrestObject
  (define %type-converter-create
    (crest-foreign-procedure "mlir::TypeConverter::TypeConverter"
                             () uptr))

  ;; The callbacks below are the addresses of C functions that Scheme made (with-c-callable/lambda or
  ;; define-c-callable in (crest callback)). C++ keeps the address and calls it for as long
  ;; as the pattern set, the target or the type converter is used, and releases nothing: the caller
  ;; keeps the function alive for that long.

  ;; @brief TypeConverter::addConversion — register a type-conversion callback: (uptr type) → uptr.
  (define %type-converter-add-conversion
    (crest-foreign-procedure "mlir::TypeConverter::addConversion"
                             (uptr uptr) void))

  ;; @brief TypeConverter::addSourceMaterialization — register a Scheme callback.
  (define %mlir::TypeConverter::addSourceMaterialization
    (crest-foreign-procedure
     "mlir::TypeConverter::addSourceMaterialization"
     (uptr uptr) void))

  ;; @brief TypeConverter::addTargetMaterialization — register a Scheme callback.
  (define %mlir::TypeConverter::addTargetMaterialization
    (crest-foreign-procedure
     "mlir::TypeConverter::addTargetMaterialization"
     (uptr uptr) void))

  ;; @brief TypeConverter::isLegal(Type).
  (define %type-converter-is-legal-type
    (crest-foreign-procedure "mlir::TypeConverter::isLegal<Type>"
                             (uptr uptr) int))

  ;; @brief TypeConverter::isLegal(Operation*).
  (define %type-converter-is-legal
    (crest-foreign-procedure "mlir::TypeConverter::isLegal<Operation>"
                             (uptr uptr) int))

  ;; @brief TypeConverter::isSignatureLegal.
  (define %type-converter-is-signature-legal
    (crest-foreign-procedure "mlir::TypeConverter::isSignatureLegal"
                             (uptr uptr) int))

  ;; @brief mlir::ConversionTarget constructor — allocate a new CrestBox<ConversionTarget>.
  ;; @param ctx MLIRContext* uptr
  ;; @return    CrestBox<ConversionTarget>* uptr — freed via with-CrestObject
  (define %target-create
    (crest-foreign-procedure "mlir::ConversionTarget::ConversionTarget"
                             (uptr) uptr))

  ;; @brief ConversionTarget::addIllegalDialect.
  (define %target-add-illegal-dialect
    (crest-foreign-procedure "mlir::ConversionTarget::addIllegalDialect"
                             (uptr string) void))

  ;; @brief ConversionTarget::addLegalDialect.
  (define %target-add-legal-dialect
    (crest-foreign-procedure "mlir::ConversionTarget::addLegalDialect"
                             (uptr string) void))

  ;; @brief ConversionTarget::addLegalOp.
  (define %target-add-legal-op
    (crest-foreign-procedure "mlir::ConversionTarget::addLegalOp"
                             (uptr uptr string) void))

  ;; @brief ConversionTarget::addDynamicallyLegalOp.
  (define %target-add-dynamically-legal-op
    (crest-foreign-procedure "mlir::ConversionTarget::addDynamicallyLegalOp"
                             (uptr uptr string uptr) void))

  ;; @brief ConversionTarget::markUnknownOpDynamicallyLegal.
  (define %target-mark-unknown-ops-dynamically-legal
    (crest-foreign-procedure
     "mlir::ConversionTarget::markUnknownOpsDynamicallyLegal"
     (uptr uptr) void))

  ;; @brief mlir::applyFullConversion.
  (define %apply-full-conversion
    (crest-foreign-procedure "mlir_transforms_dialect_conversion_apply_full_conversion"
                             (uptr uptr uptr) int))

  ;; @brief Register a Scheme ConversionPattern for a named op.
  (define %add-conversion-pattern
    (crest-foreign-procedure "crest::DialectConversion::addConversionPattern"
                             (uptr string uptr uptr int) void))

  ;; @brief Register a Scheme ConversionPattern with no TypeConverter (original operands).
  (define %add-conversion-pattern/ctx
    (crest-foreign-procedure "crest::DialectConversion::addConversionPattern/ctx"
                             (uptr string uptr int) void))

  ;; @brief Register a Scheme RewritePattern (no TypeConverter) for a named op.
  (define %add-rewrite-pattern
    (crest-foreign-procedure "crest::DialectConversion::addRewritePattern"
                             (uptr string uptr int) void))

  ;; @brief mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>.
  (define %populate-func-type-conversion
    (crest-foreign-procedure "mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>"
                             (uptr uptr) void))

  ;; @brief Type predicates.
  (define %crest::isa<CrestBox<mlir::TypeConverter>>
    (crest-foreign-procedure "crest::isa<CrestBox<mlir::TypeConverter>>" (uptr) int))

  (define %crest::isa<CrestBox<mlir::ConversionTarget>>
    (crest-foreign-procedure "crest::isa<CrestBox<mlir::ConversionTarget>>" (uptr) int))

  (define %mlir::applyPartialConversion
    (crest-foreign-procedure "mlir::applyPartialConversion" (uptr uptr uptr) int))

  (define %mlir::RewriterBase::modifyOpInPlace
    (crest-foreign-procedure "mlir::RewriterBase::modifyOpInPlace"
                             (uptr uptr uptr) void))

  ) ;; end library (mlir Transforms DialectConversion ffi)

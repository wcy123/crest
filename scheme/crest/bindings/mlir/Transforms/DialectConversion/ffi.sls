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
    %add-rewrite-pattern
    %populate-func-type-conversion
    %crest::isa<CrestOwned<mlir::TypeConverter>>
    %crest::isa<CrestOwned<mlir::ConversionTarget>>)

  (import (chezscheme))

  ;; @brief mlir::TypeConverter constructor — allocate a new CrestOwned<TypeConverter>.
  ;; @return CrestOwned<TypeConverter>* uptr — freed via with-CrestObject
  (define %type-converter-create
    (foreign-procedure "mlir::TypeConverter::TypeConverter"
                       () uptr))

  ;; @brief TypeConverter::addConversion — register a Scheme type-conversion callback.
  (define %type-converter-add-conversion
    (foreign-procedure "mlir::TypeConverter::addConversion"
                       (uptr scheme-object) void))

  ;; @brief TypeConverter::addSourceMaterialization — register a Scheme callback.
  (define %mlir::TypeConverter::addSourceMaterialization
    (foreign-procedure
     "mlir::TypeConverter::addSourceMaterialization"
     (uptr scheme-object) void))

  ;; @brief TypeConverter::addTargetMaterialization — register a Scheme callback.
  (define %mlir::TypeConverter::addTargetMaterialization
    (foreign-procedure
     "mlir::TypeConverter::addTargetMaterialization"
     (uptr scheme-object) void))

  ;; @brief TypeConverter::isLegal(Type).
  (define %type-converter-is-legal-type
    (foreign-procedure "mlir::TypeConverter::isLegal<Type>"
                       (uptr uptr) int))

  ;; @brief TypeConverter::isLegal(Operation*).
  (define %type-converter-is-legal
    (foreign-procedure "mlir::TypeConverter::isLegal<Operation>"
                       (uptr uptr) int))

  ;; @brief TypeConverter::isSignatureLegal.
  (define %type-converter-is-signature-legal
    (foreign-procedure "mlir::TypeConverter::isSignatureLegal"
                       (uptr uptr) int))

  ;; @brief mlir::ConversionTarget constructor — allocate a new CrestOwned<ConversionTarget>.
  ;; @param ctx MLIRContext* uptr
  ;; @return    CrestOwned<ConversionTarget>* uptr — freed via with-CrestObject
  (define %target-create
    (foreign-procedure "mlir::ConversionTarget::ConversionTarget"
                       (uptr) uptr))

  ;; @brief ConversionTarget::addIllegalDialect.
  (define %target-add-illegal-dialect
    (foreign-procedure "mlir::ConversionTarget::addIllegalDialect"
                       (uptr string) void))

  ;; @brief ConversionTarget::addLegalDialect.
  (define %target-add-legal-dialect
    (foreign-procedure "mlir::ConversionTarget::addLegalDialect"
                       (uptr string) void))

  ;; @brief ConversionTarget::addLegalOp.
  (define %target-add-legal-op
    (foreign-procedure "mlir::ConversionTarget::addLegalOp"
                       (uptr uptr string) void))

  ;; @brief ConversionTarget::addDynamicallyLegalOp.
  (define %target-add-dynamically-legal-op
    (foreign-procedure "mlir::ConversionTarget::addDynamicallyLegalOp"
                       (uptr uptr string scheme-object) void))

  ;; @brief ConversionTarget::markUnknownOpDynamicallyLegal.
  (define %target-mark-unknown-ops-dynamically-legal
    (foreign-procedure
     "mlir::ConversionTarget::markUnknownOpsDynamicallyLegal"
     (uptr scheme-object) void))

  ;; @brief mlir::applyFullConversion.
  (define %apply-full-conversion
    (foreign-procedure "mlir_transforms_dialect_conversion_apply_full_conversion"
                       (uptr uptr uptr) int))

  ;; @brief Register a Scheme ConversionPattern for a named op.
  (define %add-conversion-pattern
    (foreign-procedure "crest::DialectConversion::addConversionPattern"
                       (uptr string scheme-object uptr int) void))

  ;; @brief Register a Scheme RewritePattern (no TypeConverter) for a named op.
  (define %add-rewrite-pattern
    (foreign-procedure "crest::DialectConversion::addRewritePattern"
                       (uptr string scheme-object int) void))

  ;; @brief mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>.
  (define %populate-func-type-conversion
    (foreign-procedure "mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>"
                       (uptr uptr) void))

  ;; @brief Type predicates.
  (define %crest::isa<CrestOwned<mlir::TypeConverter>>
    (foreign-procedure "crest::isa<CrestOwned<mlir::TypeConverter>>" (uptr) int))

  (define %crest::isa<CrestOwned<mlir::ConversionTarget>>
    (foreign-procedure "crest::isa<CrestOwned<mlir::ConversionTarget>>" (uptr) int))

  ) ;; end library (mlir Transforms DialectConversion ffi)

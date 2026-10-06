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
   %type-converter-destroy
   %type-converter-add-conversion
   %type-converter-add-source-materialization
   %type-converter-add-target-materialization
   %type-converter-is-legal-type
   %type-converter-is-legal
   %type-converter-is-signature-legal
   %target-create
   %target-destroy
   %target-add-illegal-dialect
   %target-add-legal-dialect
   %target-add-legal-op
   %target-add-dynamically-legal-op
   %target-mark-unknown-ops-dynamically-legal
   %pattern-set-create
   %pattern-set-destroy
   %apply-full-conversion
   %add-conversion-pattern
   %add-rewrite-pattern
   %populate-func-type-conversion)

  (import (chezscheme))

  ;; @brief mlir::TypeConverter constructor — allocate a new TypeConverter.
  ;; @return TypeConverter* uptr — heap-allocated; caller must destroy with
  ;;         %type-converter-destroy
  ;; @see    mlir/Transforms/DialectConversion.h
  ;; @note   Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %type-converter-create
    (foreign-procedure "mlir_transforms_dialect_conversion_type_converter_create"
                       () uptr))

  ;; @brief mlir::TypeConverter destructor — free a TypeConverter.
  ;; @param converter TypeConverter* uptr — must not be used after this call
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %type-converter-destroy
    (foreign-procedure "mlir_transforms_dialect_conversion_type_converter_destroy"
                       (uptr) void))

  ;; @brief TypeConverter::addConversion — register a Scheme type-conversion
  ;;        callback.
  ;; @param converter TypeConverter* uptr
  ;; @param callback  Scheme procedure (lambda (type-uptr) -> type-uptr | #f);
  ;;                  #f means this conversion does not handle the type
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %type-converter-add-conversion
    (foreign-procedure "mlir_transforms_dialect_conversion_type_converter_add_conversion"
                       (uptr scheme-object) void))

  ;; @brief TypeConverter::addSourceMaterialization — register a Scheme callback
  ;;        to materialize a value of the source (pre-conversion) type.
  ;; @param converter TypeConverter* uptr
  ;; @param callback  Scheme procedure
  ;;                  (lambda (builder-uptr result-type-uptr inputs-list loc-uptr)
  ;;                    -> value-uptr | #f);
  ;;                  inputs-list is a Scheme list of value uptrs;
  ;;                  #f means not handled
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %type-converter-add-source-materialization
    (foreign-procedure
     "mlir_transforms_dialect_conversion_type_converter_add_source_materialization"
     (uptr scheme-object) void))

  ;; @brief TypeConverter::addTargetMaterialization — register a Scheme callback
  ;;        to materialize a value of the target (post-conversion) type.
  ;; @param converter TypeConverter* uptr
  ;; @param callback  Scheme procedure
  ;;                  (lambda (builder-uptr result-type-uptr inputs-list loc-uptr)
  ;;                    -> value-uptr | #f);
  ;;                  inputs-list is a Scheme list of value uptrs;
  ;;                  #f means not handled
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %type-converter-add-target-materialization
    (foreign-procedure
     "mlir_transforms_dialect_conversion_type_converter_add_target_materialization"
     (uptr scheme-object) void))

  ;; @brief TypeConverter::isLegal(Type) — test whether a single MLIR type is
  ;;        legal under this converter.
  ;; @param converter TypeConverter* uptr
  ;; @param type      Type* uptr (opaque pointer from Type::getAsOpaquePointer)
  ;; @return          1 if legal, 0 otherwise
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %type-converter-is-legal-type
    (foreign-procedure "mlir_transforms_dialect_conversion_type_converter_is_legal_type"
                       (uptr uptr) int))

  ;; @brief TypeConverter::isLegal(Operation*) — test whether all operand and
  ;;        result types of an operation are legal.
  ;; @param converter TypeConverter* uptr
  ;; @param op        Operation* uptr
  ;; @return          1 if legal, 0 otherwise
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %type-converter-is-legal
    (foreign-procedure "mlir_transforms_dialect_conversion_type_converter_is_legal"
                       (uptr uptr) int))

  ;; @brief TypeConverter::isSignatureLegal — test whether a func.func
  ;;        operation's function-type signature is fully legal.
  ;; @param converter TypeConverter* uptr
  ;; @param func-op   Operation* uptr — must be a func::FuncOp
  ;; @return          1 if legal, 0 otherwise (including if cast fails)
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %type-converter-is-signature-legal
    (foreign-procedure "mlir_transforms_dialect_conversion_type_converter_is_signature_legal"
                       (uptr uptr) int))

  ;; @brief mlir::ConversionTarget constructor — allocate a new ConversionTarget
  ;;        bound to the given MLIRContext.
  ;; @param ctx MLIRContext* uptr
  ;; @return    ConversionTarget* uptr — caller must destroy with %target-destroy
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %target-create
    (foreign-procedure "mlir_transforms_dialect_conversion_target_create"
                       (uptr) uptr))

  ;; @brief mlir::ConversionTarget destructor — free a ConversionTarget.
  ;; @param target ConversionTarget* uptr — must not be used after this call
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %target-destroy
    (foreign-procedure "mlir_transforms_dialect_conversion_target_destroy"
                       (uptr) void))

  ;; @brief ConversionTarget::addIllegalDialect — mark all ops in a dialect
  ;;        as illegal (must be converted).
  ;; @param target       ConversionTarget* uptr
  ;; @param dialect-name string — e.g. "onnx"
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %target-add-illegal-dialect
    (foreign-procedure "mlir_transforms_dialect_conversion_target_add_illegal_dialect"
                       (uptr string) void))

  ;; @brief ConversionTarget::addLegalDialect — mark all ops in a dialect
  ;;        as unconditionally legal (no conversion required).
  ;; @param target       ConversionTarget* uptr
  ;; @param dialect-name string — e.g. "arith"
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %target-add-legal-dialect
    (foreign-procedure "mlir_transforms_dialect_conversion_target_add_legal_dialect"
                       (uptr string) void))

  ;; @brief ConversionTarget::addLegalOp — mark a single op (by name) as
  ;;        unconditionally legal.
  ;; @param target  ConversionTarget* uptr
  ;; @param ctx     MLIRContext* uptr — used to intern the OperationName
  ;; @param op-name string — fully-qualified op name, e.g. "func.return"
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %target-add-legal-op
    (foreign-procedure "mlir_transforms_dialect_conversion_target_add_legal_op"
                       (uptr uptr string) void))

  ;; @brief ConversionTarget::addDynamicallyLegalOp — mark a single op as
  ;;        legal only when a Scheme predicate returns true.
  ;; @param target    ConversionTarget* uptr
  ;; @param ctx       MLIRContext* uptr
  ;; @param op-name   string — fully-qualified op name
  ;; @param callback  Scheme procedure (lambda (op-uptr) -> truthy | #f)
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %target-add-dynamically-legal-op
    (foreign-procedure "mlir_transforms_dialect_conversion_target_add_dynamically_legal_op"
                       (uptr uptr string scheme-object) void))

  ;; @brief ConversionTarget::markUnknownOpDynamicallyLegal — classify ops not
  ;;        otherwise registered using a Scheme predicate.
  ;; @param target   ConversionTarget* uptr
  ;; @param callback Scheme procedure (lambda (op-uptr) -> truthy | #f)
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %target-mark-unknown-ops-dynamically-legal
    (foreign-procedure
     "mlir_transforms_dialect_conversion_target_mark_unknown_ops_dynamically_legal"
     (uptr scheme-object) void))

  ;; @brief mlir::RewritePatternSet constructor — allocate a new pattern set
  ;;        bound to the given MLIRContext.
  ;; @param ctx MLIRContext* uptr
  ;; @return    RewritePatternSet* uptr — caller must destroy with
  ;;            %pattern-set-destroy (or pass to %apply-full-conversion which
  ;;            consumes it)
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %pattern-set-create
    (foreign-procedure "mlir_transforms_dialect_conversion_pattern_set_create"
                       (uptr) uptr))

  ;; @brief mlir::RewritePatternSet destructor — free a pattern set.
  ;; @param patterns RewritePatternSet* uptr — must not be used after this call
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %pattern-set-destroy
    (foreign-procedure "mlir_transforms_dialect_conversion_pattern_set_destroy"
                       (uptr) void))

  ;; @brief mlir::applyFullConversion — apply patterns until the target is
  ;;        satisfied; fails if any illegal op remains.
  ;; @param op       Operation* uptr — root op to convert (must be a ModuleOp)
  ;; @param target   ConversionTarget* uptr
  ;; @param patterns RewritePatternSet* uptr (consumed/moved)
  ;; @return         1 on success (conversion succeeded), 0 on failure
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %apply-full-conversion
    (foreign-procedure "mlir_transforms_dialect_conversion_apply_full_conversion"
                       (uptr uptr uptr) int))

  ;; @brief Register a Scheme ConversionPattern for a named op.  The callback
  ;;        is called as (callback op operands-ref rewriter type-converter)
  ;;        and must return #t on success or #f on failure.
  ;; @param patterns      RewritePatternSet* uptr
  ;; @param op-name       string — fully-qualified op name, e.g. "onnx.MatMul"
  ;; @param callback      Scheme procedure
  ;; @param type-converter TypeConverter* uptr
  ;; @param benefit       int — pattern benefit (higher = tried first)
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %add-conversion-pattern
    (foreign-procedure "mlir_transforms_dialect_conversion_add_conversion_pattern"
                       (uptr string scheme-object uptr int) void))

  ;; @brief Register a Scheme RewritePattern (no TypeConverter) for a named op.
  ;;        The callback is called as (callback op rewriter) and must return #t
  ;;        on success or #f on failure.
  ;; @param patterns  RewritePatternSet* uptr
  ;; @param op-name   string — fully-qualified op name
  ;; @param callback  Scheme procedure
  ;; @param benefit   int — pattern benefit (higher = tried first)
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %add-rewrite-pattern
    (foreign-procedure "mlir_transforms_dialect_conversion_add_rewrite_pattern"
                       (uptr string scheme-object int) void))

  ;; @brief mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp> —
  ;;        add the standard func.func type-conversion pattern to the set.
  ;; @param patterns  RewritePatternSet* uptr
  ;; @param converter TypeConverter* uptr
  ;; @see   mlir/Dialect/Func/Transforms/FuncConversions.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %populate-func-type-conversion
    (foreign-procedure "mlir_transforms_dialect_conversion_populate_func_type_conversion"
                       (uptr uptr) void))

  ) ;; end library (mlir Transforms DialectConversion ffi)

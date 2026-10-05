#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir transforms dialect-conversion) — MLIR Dialect Conversion Framework.
;;
;; Mirrors mlir/Transforms/DialectConversion.h: TypeConverter, ConversionTarget,
;; RewritePatternSet, applyFullConversion, and Scheme-pattern registration.
;;
;; Raw C bindings with % prefix live in (mlir transforms dialect-conversion ffi).
;;
;;===----------------------------------------------------------------------===;;

(library (mlir transforms dialect-conversion)

  (export
    type-converter-create
    type-converter-destroy
    type-converter-add-conversion
    type-converter-add-source-materialization
    type-converter-add-target-materialization
    type-converter-is-legal-type
    type-converter-is-legal
    type-converter-is-signature-legal
    target-create
    target-destroy
    target-add-illegal-dialect
    target-add-legal-dialect
    target-add-legal-op
    target-add-dynamically-legal-op
    target-mark-unknown-ops-dynamically-legal
    pattern-set-create
    pattern-set-destroy
    apply-full-conversion
    add-conversion-pattern
    add-rewrite-pattern
    populate-func-type-conversion
    with-type-converter
    with-conversion-target
    with-pattern-set)

  (import (rnrs)
          (mlir transforms dialect-conversion ffi)
          (only (mlir core builder) with-raii)
          (only (mlir ir mlir-context) current-mlir-context))

  ;; @brief mlir::TypeConverter constructor — allocate a new TypeConverter.
  ;; @return TypeConverter* uptr — heap-allocated; caller must destroy with
  ;;         type-converter-destroy
  ;; @see    mlir/Transforms/DialectConversion.h
  ;; @note   Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define type-converter-create
    %type-converter-create)

  ;; @brief mlir::TypeConverter destructor — free a TypeConverter.
  ;; @param converter TypeConverter* uptr — must not be used after this call
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define type-converter-destroy
    %type-converter-destroy)

  ;; @brief TypeConverter::addConversion — register a Scheme type-conversion
  ;;        callback.
  ;; @param converter TypeConverter* uptr
  ;; @param callback  Scheme procedure (lambda (type-uptr) -> type-uptr | #f);
  ;;                  #f means this conversion does not handle the type
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define type-converter-add-conversion
    %type-converter-add-conversion)

  ;; @brief TypeConverter::addSourceMaterialization — register a Scheme callback
  ;;        to produce a source-type value from a converted one.
  ;; @param converter TypeConverter* uptr
  ;; @param callback  Scheme procedure
  ;;                  (lambda (builder-uptr result-type-uptr inputs-list loc-uptr)
  ;;                    -> value-uptr | #f)
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define type-converter-add-source-materialization
    %type-converter-add-source-materialization)

  ;; @brief TypeConverter::addTargetMaterialization — register a Scheme callback
  ;;        to produce a tarmlir::Value::getType value from an unconverted one.
  ;; @param converter TypeConverter* uptr
  ;; @param callback  Scheme procedure
  ;;                  (lambda (builder-uptr result-type-uptr inputs-list loc-uptr)
  ;;                    -> value-uptr | #f)
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define type-converter-add-target-materialization
    %type-converter-add-target-materialization)

  ;; @brief TypeConverter::isLegal(Type) — test whether a single MLIR type is
  ;;        legal under this converter.
  ;; @param converter TypeConverter* uptr
  ;; @param type      Type* uptr (opaque pointer from Type::getAsOpaquePointer)
  ;; @return          1 if legal, 0 otherwise
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define type-converter-is-legal-type
    %type-converter-is-legal-type)

  ;; @brief TypeConverter::isLegal(Operation*) — test whether all operand and
  ;;        result types of an operation are legal.
  ;; @param converter TypeConverter* uptr
  ;; @param op        Operation* uptr
  ;; @return          1 if legal, 0 otherwise
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define type-converter-is-legal
    %type-converter-is-legal)

  ;; @brief TypeConverter::isSignatureLegal — test whether a func.func
  ;;        operation's function-type signature is fully legal.
  ;; @param converter TypeConverter* uptr
  ;; @param func-op   Operation* uptr — must be a func::FuncOp
  ;; @return          1 if legal, 0 otherwise (including if cast fails)
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define type-converter-is-signature-legal
    %type-converter-is-signature-legal)

  ;; @brief mlir::ConversionTarget constructor — allocate a new ConversionTarget
  ;;        bound to the given MLIRContext.
  ;; @param ctx MLIRContext* uptr
  ;; @return    ConversionTarget* uptr — caller must destroy with target-destroy
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define target-create
    %target-create)

  ;; @brief mlir::ConversionTarget destructor — free a ConversionTarget.
  ;; @param target ConversionTarget* uptr — must not be used after this call
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define target-destroy
    %target-destroy)

  ;; @brief ConversionTarget::addIllegalDialect — mark all ops in a dialect
  ;;        as illegal (must be converted).
  ;; @param target       ConversionTarget* uptr
  ;; @param dialect-name string — e.g. "onnx"
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define target-add-illegal-dialect
    %target-add-illegal-dialect)

  ;; @brief ConversionTarget::addLegalDialect — mark all ops in a dialect
  ;;        as unconditionally legal (no conversion required).
  ;; @param target       ConversionTarget* uptr
  ;; @param dialect-name string — e.g. "arith"
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define target-add-legal-dialect
    %target-add-legal-dialect)

  ;; @brief ConversionTarget::addLegalOp — mark a single op (by name) as
  ;;        unconditionally legal.
  ;; @param target  ConversionTarget* uptr
  ;; @param ctx     MLIRContext* uptr — used to intern the OperationName
  ;; @param op-name string — fully-qualified op name, e.g. "func.return"
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define target-add-legal-op
    %target-add-legal-op)

  ;; @brief ConversionTarget::addDynamicallyLegalOp — mark a single op as
  ;;        legal only when a Scheme predicate returns true.
  ;; @param target    ConversionTarget* uptr
  ;; @param ctx       MLIRContext* uptr
  ;; @param op-name   string — fully-qualified op name
  ;; @param callback  Scheme procedure (lambda (op-uptr) -> truthy | #f)
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define target-add-dynamically-legal-op
    %target-add-dynamically-legal-op)

  ;; @brief ConversionTarget::markUnknownOpDynamicallyLegal — classify ops not
  ;;        otherwise registered using a Scheme predicate.
  ;; @param target   ConversionTarget* uptr
  ;; @param callback Scheme procedure (lambda (op-uptr) -> truthy | #f)
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define target-mark-unknown-ops-dynamically-legal
    %target-mark-unknown-ops-dynamically-legal)

  ;; @brief mlir::RewritePatternSet constructor — allocate a new pattern set
  ;;        bound to the given MLIRContext.
  ;; @param ctx MLIRContext* uptr
  ;; @return    RewritePatternSet* uptr — caller must destroy with
  ;;            pattern-set-destroy (or pass to apply-full-conversion which
  ;;            consumes it)
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define pattern-set-create
    %pattern-set-create)

  ;; @brief mlir::RewritePatternSet destructor — free a pattern set.
  ;; @param patterns RewritePatternSet* uptr — must not be used after this call
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define pattern-set-destroy
    %pattern-set-destroy)

  ;; @brief mlir::applyFullConversion — apply patterns until the target is
  ;;        satisfied; fails if any illegal op remains.
  ;; @param op       Operation* uptr — root op to convert (must be a ModuleOp)
  ;; @param target   ConversionTarget* uptr
  ;; @param patterns RewritePatternSet* uptr (consumed/moved)
  ;; @return         1 on success (conversion succeeded), 0 on failure
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define apply-full-conversion
    %apply-full-conversion)

  ;; @brief Register a Scheme ConversionPattern for a named op.  The callback
  ;;        is called as (callback op operands-ref rewriter type-converter)
  ;;        and must return #t on success or #f on failure.
  ;; @param patterns       RewritePatternSet* uptr
  ;; @param op-name        string — fully-qualified op name, e.g. "onnx.MatMul"
  ;; @param callback       Scheme procedure
  ;; @param type-converter TypeConverter* uptr
  ;; @param benefit        int — pattern benefit (higher = tried first)
  ;; @see   mlir/Transforms/DialectConversion.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define add-conversion-pattern
    %add-conversion-pattern)

  ;; @brief Register a Scheme RewritePattern (no TypeConverter) for a named op.
  ;;        The callback is called as (callback op rewriter) and must return #t
  ;;        on success or #f on failure.
  ;; @param patterns RewritePatternSet* uptr
  ;; @param op-name  string — fully-qualified op name
  ;; @param callback Scheme procedure
  ;; @param benefit  int — pattern benefit (higher = tried first)
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define add-rewrite-pattern
    %add-rewrite-pattern)

  ;; @brief mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp> —
  ;;        add the standard func.func type-conversion pattern to the set.
  ;; @param patterns  RewritePatternSet* uptr
  ;; @param converter TypeConverter* uptr
  ;; @see   mlir/Dialect/Func/Transforms/FuncConversions.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define populate-func-type-conversion
    %populate-func-type-conversion)

  ;; @brief RAII macro — create a TypeConverter, bind it to VAR, execute BODY,
  ;;        then unconditionally destroy the converter on exit.
  ;; @param var  identifier bound to the TypeConverter* uptr for BODY
  ;; @param body forms to evaluate with var in scope
  ;; @example
  ;;   (with-type-converter (tc)
  ;;     (type-converter-add-conversion tc my-fn)
  ;;     ...)
  (define-syntax with-type-converter
    (syntax-rules ()
      [(_ (var) body ...)
       (with-raii (var (type-converter-create) type-converter-destroy)
         body ...)]))

  ;; @brief RAII macro — create a ConversionTarget for CTX, bind it to VAR,
  ;;        execute BODY, then unconditionally destroy the target on exit.
  ;; @param var identifier bound to the ConversionTarget* uptr for BODY
  ;; @param ctx MLIRContext* uptr (optional; defaults to current-mlir-context)
  ;; @param body forms to evaluate with var in scope
  ;; @example
  ;;   (with-conversion-target (tgt)
  ;;     (target-add-illegal-dialect tgt "onnx")
  ;;     ...)
  ;;   (with-conversion-target (tgt ctx)
  ;;     (target-add-illegal-dialect tgt "onnx")
  ;;     ...)
  (define-syntax with-conversion-target
    (syntax-rules ()
      [(_ (var) body ...)
       (with-raii (var (target-create (current-mlir-context)) target-destroy)
         body ...)]
      [(_ (var ctx) body ...)
       (with-raii (var (target-create ctx) target-destroy)
         body ...)]))

  ;; @brief RAII macro — create a RewritePatternSet for CTX, bind it to VAR,
  ;;        execute BODY, then unconditionally destroy the pattern set on exit.
  ;; @param var  identifier bound to the RewritePatternSet* uptr for BODY
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-mlir-context)
  ;; @param body forms to evaluate with var in scope
  ;; @note  If BODY passes VAR to apply-full-conversion the set is consumed
  ;;        (moved); the subsequent destroy is then a no-op (the C++ side checks
  ;;        the pointer).
  ;; @example
  ;;   (with-pattern-set (ps)
  ;;     (add-conversion-pattern ps "onnx.MatMul" my-pattern tc 1)
  ;;     (apply-full-conversion op tgt ps))
  ;;   (with-pattern-set (ps ctx)
  ;;     (add-conversion-pattern ps "onnx.MatMul" my-pattern tc 1)
  ;;     (apply-full-conversion op tgt ps))
  (define-syntax with-pattern-set
    (syntax-rules ()
      [(_ (var) body ...)
       (with-raii (var (pattern-set-create (current-mlir-context)) pattern-set-destroy)
         body ...)]
      [(_ (var ctx) body ...)
       (with-raii (var (pattern-set-create ctx) pattern-set-destroy)
         body ...)]))

) ;; end library (mlir transforms dialect-conversion)

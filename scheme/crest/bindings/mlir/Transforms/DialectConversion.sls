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
    mlir::applyPartialConversion
    mlir::RewriterBase::modifyOpInPlace
    add-conversion-pattern
    add-conversion-pattern/ctx
    add-rewrite-pattern
    populate-func-type-conversion
    crest::isa<CrestBox<mlir::TypeConverter>>?
    crest::isa<CrestBox<mlir::ConversionTarget>>?
    with-TypeConverter
    with-ConversionTarget
    )

  (import (rnrs)
          (crest callback)
          (mlir Transforms DialectConversion ffi)
          (only (mlir IR PatternMatch)
                mlir::RewritePatternSet::RewritePatternSet)
          (only (mlir support CrestObject) with-CrestObject)
          (only (mlir IR MLIRContext) current-MLIRContext))

  ;; @brief mlir::TypeConverter constructor — allocate a new TypeConverter.
  ;; @return CrestBox<TypeConverter>* uptr — freed via with-CrestObject
  (define type-converter-create
    %type-converter-create)

  ;; The callbacks that the procedures below take are closures for one conversion: C++ makes each
  ;; into a C function (crest::ForeignCallable::fromProcedure) that it releases when what calls it is
  ;; destroyed (the pattern set, the target or the type converter). What is given to C++ is the
  ;; procedure that adapts the user's to the C types. A procedure that is not one is an error now,
  ;; when it is given, not when it is called.
  (define (%%procedure who proc)
    (unless (procedure? proc)
      (assertion-violation who "the callback must be a procedure" proc))
    proc)

  ;; @brief TypeConverter::addConversion — register a Scheme type-conversion callback.
  ;; @param proc (type) → the converted type, or #f when this conversion does not apply
  (define (type-converter-add-conversion converter proc)
    (%%procedure 'type-converter-add-conversion proc)
    (%type-converter-add-conversion
     converter
     (lambda (type) (or (proc type) 0))))

  ;; The materialization callbacks: (builder result-type inputs loc) → the Value, or #f
  (define (%%materialization who proc)
    (%%procedure who proc)
    (lambda (builder result-type inputs input-count loc)
      (or (proc builder result-type (crest-callback-pointer-list inputs input-count) loc) 0)))

  ;; @brief TypeConverter::addSourceMaterialization.
  (define (mlir::TypeConverter::addSourceMaterialization converter proc)
    (%mlir::TypeConverter::addSourceMaterialization
     converter
     (%%materialization 'mlir::TypeConverter::addSourceMaterialization proc)))

  ;; @brief TypeConverter::addTargetMaterialization.
  (define (mlir::TypeConverter::addTargetMaterialization converter proc)
    (%mlir::TypeConverter::addTargetMaterialization
     converter
     (%%materialization 'mlir::TypeConverter::addTargetMaterialization proc)))

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
  ;; @return    CrestBox<ConversionTarget>* uptr — freed via with-CrestObject
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

  ;; A legality callback (op) → boolean: legal when it answers neither #f nor 0.
  (define (%%legality who proc)
    (%%procedure who proc)
    (lambda (op)
      (let ([legal (proc op)])
        (if (and legal (not (eqv? legal 0))) 1 0))))

  ;; @brief ConversionTarget::addDynamicallyLegalOp.
  (define (target-add-dynamically-legal-op target ctx op-name proc)
    (%target-add-dynamically-legal-op
     target ctx op-name (%%legality 'target-add-dynamically-legal-op proc)))

  ;; @brief ConversionTarget::markUnknownOpDynamicallyLegal.
  (define (target-mark-unknown-ops-dynamically-legal target proc)
    (%target-mark-unknown-ops-dynamically-legal
     target (%%legality 'target-mark-unknown-ops-dynamically-legal proc)))

  ;; @brief mlir::RewritePatternSet constructor.
  ;; @param ctx MLIRContext* uptr
  ;; @return    CrestBox<RewritePatternSet>* uptr — freed via with-CrestObject
  (define pattern-set-create
    mlir::RewritePatternSet::RewritePatternSet)

  ;; @brief mlir::applyFullConversion.
  (define apply-full-conversion
    %apply-full-conversion)

  (define mlir::applyPartialConversion  %mlir::applyPartialConversion)
  ;; @brief RewriterBase::modifyOpInPlace: THUNK changes the op, and the rewriter is told.
  ;; THUNK is an expression for a procedure of no arguments (or a code object that the caller made and
  ;; locked, see with-c-callable). It is a C function for the length of the call and released when it
  ;; returns, also on an error. A macro.
  (define-syntax mlir::RewriterBase::modifyOpInPlace
    (syntax-rules ()
      [(_ rewriter op thunk)
       (with-c-callable (c-thunk () void thunk)
         (%mlir::RewriterBase::modifyOpInPlace rewriter op c-thunk))]))

  ;; The callback of a pattern succeeds when it answers #t (and only #t).
  (define (%%conversion-pattern who proc)
    (%%procedure who proc)
    (lambda (op operands rewriter type-converter)
      (if (eq? (proc op operands rewriter type-converter) #t) 1 0)))

  ;; @brief Register a Scheme ConversionPattern.
  ;; @param proc (op operands-ref rewriter type-converter) → #t when it rewrote the op
  (define (add-conversion-pattern patterns op-name proc type-converter benefit)
    (%add-conversion-pattern
     patterns op-name (%%conversion-pattern 'add-conversion-pattern proc) type-converter benefit))

  ;; @brief Register a Scheme ConversionPattern with no TypeConverter.
  ;; Operands passed as original (unconverted) values. Use when the pattern
  ;; reads the original operand types directly (e.g. memref.load on the input).
  (define (add-conversion-pattern/ctx patterns op-name proc benefit)
    (%add-conversion-pattern/ctx
     patterns op-name (%%conversion-pattern 'add-conversion-pattern/ctx proc) benefit))

  ;; @brief Register a Scheme RewritePattern (no TypeConverter).
  ;; @param proc (op rewriter) → #t when it rewrote the op
  (define (add-rewrite-pattern patterns op-name proc benefit)
    (%%procedure 'add-rewrite-pattern proc)
    (%add-rewrite-pattern
     patterns op-name
     (lambda (op rewriter) (if (eq? (proc op rewriter) #t) 1 0))
     benefit))

  ;; @brief mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>.
  (define populate-func-type-conversion
    %populate-func-type-conversion)

  ;; @brief crest::isa<CrestBox<mlir::TypeConverter>>? — is this ptr a CrestBox<mlir::TypeConverter>?
  (define (crest::isa<CrestBox<mlir::TypeConverter>>? ptr)
    (not (zero? (%crest::isa<CrestBox<mlir::TypeConverter>> ptr))))

  ;; @brief crest::isa<CrestBox<mlir::ConversionTarget>>? — is this ptr a CrestBox<mlir::ConversionTarget>?
  (define (crest::isa<CrestBox<mlir::ConversionTarget>>? ptr)
    (not (zero? (%crest::isa<CrestBox<mlir::ConversionTarget>> ptr))))

  ;; @brief RAII macro — create a TypeConverter, execute BODY, then destroy on exit.
  ;; @param var  identifier bound to the CrestBox<TypeConverter>* uptr for BODY
  ;; @example
  ;;   (with-TypeConverter tc ()
  ;;     (type-converter-add-conversion tc my-fn)
  ;;     ...)
  (define-syntax with-TypeConverter
    (syntax-rules ()
      [(_ var () body ...)
       (with-CrestObject var (type-converter-create)
         body ...)]))

  ;; @brief RAII macro — create a ConversionTarget, execute BODY, then destroy on exit.
  ;; @param var identifier bound to the CrestBox<ConversionTarget>* uptr for BODY
  ;; @param ctx MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @example
  ;;   (with-ConversionTarget tgt ()
  ;;     (target-add-illegal-dialect tgt "onnx")
  ;;     ...)
  (define-syntax with-ConversionTarget
    (syntax-rules ()
      [(_ var () body ...)
       (with-CrestObject var (target-create (current-MLIRContext))
         body ...)]
      [(_ var (ctx) body ...)
       (with-CrestObject var (target-create ctx)
         body ...)]))

  ) ;; end library (mlir Transforms DialectConversion)

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
    legality->c
    type-conversion->c
    materialization->c
    )

  (import (rnrs)
          (for (rnrs) expand)
          (for (only (chezscheme) syntax->list) expand)
          (for (mlir Transforms DialectConversion options) expand)
          (crest callback)
          (mlir support with)
          (mlir Transforms DialectConversion ffi)
          (only (mlir support CrestObject) with-CrestObject)
          (only (mlir IR MLIRContext) current-MLIRContext))

  ;; @brief mlir::TypeConverter constructor — allocate a new TypeConverter.
  ;; @return CrestBox<TypeConverter>* uptr — freed via with-CrestObject
  (define type-converter-create
    %type-converter-create)

  ;; The callbacks of the procedures below are C functions that Scheme makes of the user's closures,
  ;; and C++ keeps their addresses for as long as the type converter, the target or the pattern set is
  ;; used: the caller keeps each function alive for that long (with-c-callable/lambda, or
  ;; crest-make-static-c-callable for the whole program). The procedures that take one take its
  ;; address; the with-TypeConverter and with-ConversionTarget clauses below make the functions around
  ;; their body (the C result types are int for a verdict and uptr for a type or a value), and the
  ;; adapters make a procedure with the C types of a friendly one:
  ;;
  ;;   (with-c-callable/lambda (legal (uptr) int (legality->c (lambda (op) ...)))
  ;;     (target-add-dynamically-legal-op target ctx "func.func" legal)
  ;;     ...)
  ;;
  ;;
  ;; The C prototypes: a type conversion (type) → type or 0, a materialization (builder result-type
  ;; inputs count loc) → value or 0 with the inputs as a pointer and a count, a legality check (op) → 1
  ;; or 0, a conversion pattern (op operands rewriter type-converter) → 1 or 0, a rewrite pattern
  ;; (op rewriter) → 1 or 0 (their adapters are in (mlir IR PatternMatch)); every argument is an
  ;; address or an integer (uptr). An error of the procedure is a diagnostic at its Scheme source, and the
  ;; C function answers 0.

  ;; A type conversion: (type) → the converted type, or #f when this conversion does not apply.
  (define (type-conversion->c proc)
    (lambda (type) (or (proc type) 0)))

  ;; A materialization: (builder result-type inputs loc) → the Value, or #f; inputs is a list.
  (define (materialization->c proc)
    (lambda (builder result-type inputs input-count loc)
      (or (proc builder result-type (crest-callback-pointer-list inputs input-count) loc) 0)))

  ;; A legality check (op) → boolean: legal when it answers neither #f nor 0.
  (define (legality->c proc)
    (lambda (op)
      (let ([legal (proc op)])
        (if (and legal (not (eqv? legal 0))) 1 0))))

  ;; The callable that the functions below take is an address, not a procedure: C++ keeps it. The
  ;; error for a procedure says how to make one.
  (define (%%callable who callable)
    (unless (and (integer? callable) (exact? callable))
      (assertion-violation
       who
       "the callback must be the address of a C function: make it with crest-make-static-c-callable, or with with-c-callable/lambda around the use; the clauses of with-TypeConverter, with-ConversionTarget and with-RewritePatternSet take procedures"
       callable))
    callable)

  ;; @brief TypeConverter::addConversion: CALLABLE is the address of a C function (type) → type or 0.
  (define (type-converter-add-conversion converter callable)
    (%type-converter-add-conversion converter (%%callable 'type-converter-add-conversion callable)))

  ;; @brief TypeConverter::addSourceMaterialization: CALLABLE is the address of a C function.
  (define (mlir::TypeConverter::addSourceMaterialization converter callable)
    (%mlir::TypeConverter::addSourceMaterialization
     converter (%%callable 'mlir::TypeConverter::addSourceMaterialization callable)))

  ;; @brief TypeConverter::addTargetMaterialization: CALLABLE is the address of a C function.
  (define (mlir::TypeConverter::addTargetMaterialization converter callable)
    (%mlir::TypeConverter::addTargetMaterialization
     converter (%%callable 'mlir::TypeConverter::addTargetMaterialization callable)))

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

  ;; @brief ConversionTarget::addDynamicallyLegalOp: CALLABLE is the address of a C function (op) → 1 or 0.
  (define (target-add-dynamically-legal-op target ctx op-name callable)
    (%target-add-dynamically-legal-op
     target ctx op-name (%%callable 'target-add-dynamically-legal-op callable)))

  ;; @brief ConversionTarget::markUnknownOpDynamicallyLegal: CALLABLE is the address of a C function.
  (define (target-mark-unknown-ops-dynamically-legal target callable)
    (%target-mark-unknown-ops-dynamically-legal
     target (%%callable 'target-mark-unknown-ops-dynamically-legal callable)))

  ;; @brief mlir::applyFullConversion.
  (define apply-full-conversion
    %apply-full-conversion)

  (define mlir::applyPartialConversion  %mlir::applyPartialConversion)
  ;; @brief RewriterBase::modifyOpInPlace: THUNK changes the op, and the rewriter is told.
  ;; THUNK is an expression for a procedure of no arguments (or a code object that the caller made and
  ;; locked, see with-c-callable/lambda). It is a C function for the length of the call and released when it
  ;; returns, also on an error. MLIR's callback is void, so an error of THUNK ends the process with the
  ;; text of the error. A macro.
  (define-syntax mlir::RewriterBase::modifyOpInPlace
    (syntax-rules ()
      [(_ rewriter op thunk)
       (with-c-callable/lambda (c-thunk () void thunk)
         (%mlir::RewriterBase::modifyOpInPlace rewriter op c-thunk))]))

  ;; @brief Register a Scheme ConversionPattern. CALLABLE is the address of a C function
  ;; (op operands-ref rewriter type-converter) → 1 or 0 (see conversion-pattern->c).
  (define (add-conversion-pattern patterns op-name callable type-converter benefit)
    (%add-conversion-pattern patterns op-name (%%callable 'add-conversion-pattern callable)
                             type-converter benefit))

  ;; @brief Register a Scheme ConversionPattern with no TypeConverter.
  ;; Operands passed as original (unconverted) values. Use when the pattern
  ;; reads the original operand types directly (e.g. memref.load on the input).
  (define (add-conversion-pattern/ctx patterns op-name callable benefit)
    (%add-conversion-pattern/ctx patterns op-name (%%callable 'add-conversion-pattern/ctx callable)
                                 benefit))

  ;; @brief Register a Scheme RewritePattern (no TypeConverter).
  ;; CALLABLE is the address of a C function (op rewriter) → 1 or 0 (see rewrite-pattern->c).
  (define (add-rewrite-pattern patterns op-name callable benefit)
    (%add-rewrite-pattern patterns op-name (%%callable 'add-rewrite-pattern callable) benefit))

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
  ;; The options give the callbacks of the converter as ordinary procedures; they are C functions for
  ;; the length of BODY and released after it:
  ;;   :conversions              (proc ...)  (type) → the converted type, or #f; added in this order
  ;;   :source-materializations  (proc ...)  (builder result-type inputs loc) → a Value or #f
  ;;   :target-materializations  (proc ...)  the same
  ;; @example
  ;;   (with-TypeConverter type-converter :conversions ((lambda (type) type))
  ;;     ...)
  (define-syntax with-TypeConverter
    (lambda (stx)
      (syntax-case stx ()
        [(_ var item ...)
         (let-values ([(options body)
                       (conversion-leading-options
                        'with-TypeConverter stx (syntax->list #'(item ...))
                        '(:conversions :source-materializations :target-materializations))])
           (with-syntax ([(conversion ...) (conversion-option-list options ':conversions)]
                         [(source ...) (conversion-option-list options ':source-materializations)]
                         [(target ...) (conversion-option-list options ':target-materializations)]
                         [(form ...) body])
             (with-syntax ([(conversion-callable ...) (generate-temporaries #'(conversion ...))]
                           [(source-callable ...) (generate-temporaries #'(source ...))]
                           [(target-callable ...) (generate-temporaries #'(target ...))])
               #'(with-CrestObject var (type-converter-create)
                   (with*
                       ((with-c-callable/lambda (conversion-callable (uptr) uptr (type-conversion->c conversion))) ...
                        (with-c-callable/lambda (source-callable (uptr uptr uptr uptr uptr) uptr
                                                                 (materialization->c source))) ...
                                                                 (with-c-callable/lambda (target-callable (uptr uptr uptr uptr uptr) uptr
                                                                                                          (materialization->c target))) ...)
                     (type-converter-add-conversion var conversion-callable) ...
                     (mlir::TypeConverter::addSourceMaterialization var source-callable) ...
                     (mlir::TypeConverter::addTargetMaterialization var target-callable) ...
                     form ...)))))])))

  ;; @brief RAII macro — create a ConversionTarget, execute BODY, then destroy on exit.
  ;; @param var identifier bound to the CrestBox<ConversionTarget>* uptr for BODY
  ;; @param ctx MLIRContext* uptr (optional, first; defaults to current-MLIRContext)
  ;; The options give the legality checks as ordinary procedures (op) → boolean; they are C functions
  ;; for the length of BODY and released after it:
  ;;   :dynamically-legal  ((op-name proc) ...)
  ;;   :unknown-legal      proc, for the ops that nothing else says anything about
  ;; @example
  ;;   (with-ConversionTarget tgt (ctx :dynamically-legal (("func.func" (lambda (op) ...))))
  ;;     (target-add-illegal-dialect tgt "onnx")
  ;;     ...)
  (define-syntax with-ConversionTarget
    (lambda (stx)
      (syntax-case stx ()
        [(_ var (argument ...) body ...)
         (let* ([arguments (syntax->list #'(argument ...))]
                [has-context? (and (pair? arguments) (not (conversion-keyword? (car arguments))))]
                [options (conversion-options
                          'with-ConversionTarget stx
                          (if has-context? (cdr arguments) arguments)
                          '(:dynamically-legal :unknown-legal))]
                [entries (conversion-option-list options ':dynamically-legal)]
                [unknown (assq ':unknown-legal options)])
           (with-syntax ([context-expression (if has-context? (car arguments) #'(current-MLIRContext))]
                         [((legal-name legal-proc) ...)
                          (map (lambda (entry)
                                 (syntax-case entry ()
                                   [(name proc) #'(name proc)]
                                   [_ (syntax-violation 'with-ConversionTarget
                                                        "a :dynamically-legal entry is (op-name proc)"
                                                        stx entry)]))
                               entries)]
                         [(unknown-proc ...) (if unknown (list (cdr unknown)) '())])
             (with-syntax ([(legal-callable ...) (generate-temporaries #'(legal-name ...))]
                           [(unknown-callable ...) (generate-temporaries #'(unknown-proc ...))])
               #'(let ([context context-expression])
                   (with-CrestObject var (target-create context)
                     (with*
                         ((with-c-callable/lambda (legal-callable (uptr) int (legality->c legal-proc))) ...
                          (with-c-callable/lambda (unknown-callable (uptr) int (legality->c unknown-proc))) ...)
                       (target-add-dynamically-legal-op var context legal-name legal-callable) ...
                       (target-mark-unknown-ops-dynamically-legal var unknown-callable) ...
                       body ...))))))])))

  ) ;; end library (mlir Transforms DialectConversion)

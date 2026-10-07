#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR PatternMatch) — RewriterBase user-visible API.
;;
;; Mirrors mlir/IR/PatternMatch.h RewriterBase.
;; Re-exports clean names from (mlir IR PatternMatch ffi).
;; Also provides RAII macros for builder context.
;;
;; Builder threading: the builder (RewriterBase* or OpBuilder*) is passed
;; explicitly to mlir-build-operation and rewriter-create-op. Since
;; mlir::RewriterBase inherits from mlir::OpBuilder, a single C++ binding
;; (%mlir::OpBuilder::create<OperationState>) handles both.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR PatternMatch)
  (export
    ;; Clean-name re-exports from ffi
    rewriter-create-op
    mlir::RewriterBase::setInsertionPoint          ;; canonical: mlir::RewriterBase::setInsertionPoint(op)
    mlir::RewriterBase::setInsertionPoint-before   ;; backward-compat alias
    mlir::RewriterBase::setInsertionPoint-to-end
    mlir::RewriterBase::createBlock
    mlir::RewriterBase::replaceOp
    mlir::RewriterBase::eraseOp
    ;; Context-dispatching constructor (explicit builder)
    mlir-build-operation
    ;; RAII macros
    with-raii
    with-RewritePatternSet
    with-RewriterBase
    with-current-OpBuilder
    with-OpBuilder)

  (import (rnrs)
          (only (mlir support RAII) with-raii)
          (only (chezscheme) make-parameter parameterize void)
          (only (mlir IR PatternMatch ffi)
                %mlir::RewriterBase::setInsertionPoint
                %mlir::RewriterBase::setInsertionPoint-before
                %mlir::RewriterBase::setInsertionPoint-to-end
                %mlir::RewriterBase::createBlock
                %mlir::RewriterBase::replaceOp
                %mlir::RewriterBase::eraseOp
                %mlir::RewriterBase::create<OperationState>
                %mlir::RewritePatternSet::RewritePatternSet
                %mlir::RewritePatternSet::~RewritePatternSet)
          (only (mlir IR Builders ffi)
                %mlir::OpBuilder::atBlockEnd
                %mlir::OpBuilder::~OpBuilder
                %mlir::OpBuilder::create<OperationState>
                %mlir::OpBuilder::getContext)
          (only (mlir IR MLIRContext) current-MLIRContext)
          (only (mlir IR Location) mlir::UnknownLoc::get)
          (only (mlir IR Operation)
                mlir::Operation::getContext
                mlir::Operation::getLoc)
          (only (mlir IR OperationSupport)
                %mlir::OperationState::addOperands
                %mlir::OperationState::addTypes
                %mlir::OperationState::addRegion
                %mlir::OperationState::~OperationState
                with-OperationState))

  (define mlir-Operation::getContext mlir::Operation::getContext)

  (define mlir::RewriterBase::setInsertionPoint       %mlir::RewriterBase::setInsertionPoint)
  (define mlir::RewriterBase::setInsertionPoint-before %mlir::RewriterBase::setInsertionPoint)
  (define mlir::RewriterBase::setInsertionPoint-to-end %mlir::RewriterBase::setInsertionPoint-to-end)
  (define mlir::RewriterBase::createBlock             %mlir::RewriterBase::createBlock)
  (define mlir::RewriterBase::replaceOp               %mlir::RewriterBase::replaceOp)
  (define mlir::RewriterBase::eraseOp                 %mlir::RewriterBase::eraseOp)

  ;; Pure Scheme helpers — compose raw C++ primitives.
  ;;
  ;; mlir::RewriterBase inherits from mlir::OpBuilder, so a single C++ binding
  ;; (%mlir::OpBuilder::create<OperationState>) works for both RewriterBase* and
  ;; OpBuilder* pointers. The caller passes whichever builder is active.
  ;;
  ;; Insertion point: managed by the BUILDER's own state.
  ;;   with-RewriterBase calls setInsertionPoint once at install.
  ;;   After each create(), the builder advances its position naturally.
  ;;
  ;; Location for the OperationState:
  ;;   rewriter-create-op (explicit loc arg): caller provides mlir::Location uptr
  ;;   3/4-arg mlir-build-operation: mlir::UnknownLoc::get
  ;;   5-arg mlir-build-operation: explicit source-loc from #'op annotation

  ;; @brief Create an op via any builder (RewriterBase* or OpBuilder*).
  ;; @param builder    OpBuilder* uptr (RewriterBase* also accepted — it IS an OpBuilder)
  ;; @param source-loc mlir::Location uptr
  ;; @param name       string — registered op name (e.g. "arith.addi")
  ;; @param operands   Scheme list of Value* uptrs
  ;; @param types      Scheme list of Type* uptrs
  ;; @param nregions   number of empty regions to add (optional, default 0)
  ;; rewriter-create-op — for RewriterBase* builders (always uses RewriterBase::create).
  ;; Uses %mlir::RewriterBase::create<OperationState> which casts to RewriterBase* —
  ;; this is required because RewriterBase introduces virtual methods, making
  ;; reinterpret_cast<OpBuilder*>(rewriterBase) unsound (vtable pointer mismatch).
  (define rewriter-create-op
    (let ([build (lambda (rw source-loc name operands types nregions)
                   (with-OperationState (state source-loc name)
                                        (for-each (lambda (v) (%mlir::OperationState::addOperands state v)) operands)
                                        (for-each (lambda (t) (%mlir::OperationState::addTypes state t)) types)
                                        (let loop ([i 0])
                                          (when (< i nregions)
                                            (%mlir::OperationState::addRegion state)
                                            (loop (+ i 1))))
                                        (%mlir::RewriterBase::create<OperationState> rw state)))])
      (case-lambda
       [(rw source-loc name operands types)
        (build rw source-loc name operands types 0)]
       [(rw source-loc name operands types nregions)
        (build rw source-loc name operands types nregions)])))

  ;; @brief Explicit-builder op constructor for samples that call it directly.
  ;; The first argument MUST be a RewriterBase* (not a plain OpBuilder*).
  ;; (rw name operands types)                    — UnknownLoc
  ;; (rw name operands types nregions)           — UnknownLoc, with regions
  ;; (rw name operands types source-loc nregions) — explicit mlir::Location
  (define mlir-build-operation
    (let ([build (lambda (rw name operands types source-loc nregions)
                   (rewriter-create-op rw source-loc name operands types nregions))]
          [default-nregions 0])
      (case-lambda
       [(rw name operands types)
        (build rw name operands types (mlir::UnknownLoc::get) default-nregions)]
       [(rw name operands types nregions)
        (build rw name operands types (mlir::UnknownLoc::get) nregions)]
       [(rw name operands types source-loc nregions)
        (build rw name operands types source-loc nregions)])))

  ;; @brief with-RewriterBase — install a RewriterBase and set its initial insertion point.
  ;; @param rw           RewriterBase* uptr (ConversionPatternRewriter or IRRewriter)
  ;; @param insert-point Operation* uptr — setInsertionPoint is called once here.
  ;;        The builder advances its own position after each create().
  (define-syntax with-RewriterBase
    (syntax-rules ()
      [(_ (rw insert-point) body ...)
       (begin
         (mlir::RewriterBase::setInsertionPoint rw insert-point)
         (parameterize ([current-MLIRContext (mlir-Operation::getContext insert-point)])
           body ...))]))

  ;; @brief with-current-OpBuilder — install an existing OpBuilder*.
  ;; @param builder      OpBuilder* uptr — already positioned by caller
  ;; @param insert-point Operation* uptr — used only to derive current-MLIRContext
  (define-syntax with-current-OpBuilder
    (syntax-rules ()
      [(_ (builder insert-point) body ...)
       (parameterize ([current-MLIRContext (mlir-Operation::getContext insert-point)])
         body ...)]))

  ;; @brief with-OpBuilder — heap-allocate an OpBuilder at block end, run body, destroy.
  ;; @param block  Block* uptr — the builder is positioned at block->end() on creation
  ;; Note: the OpBuilder is exposed as %builder within body for explicit threading.
  (define-syntax with-OpBuilder
    (syntax-rules ()
      [(_ block body ...)
       (let ([%builder (%mlir::OpBuilder::atBlockEnd block)])
         (dynamic-wind
             (lambda () #f)
             (lambda ()
               (parameterize ([current-MLIRContext (%mlir::OpBuilder::getContext %builder)])
                 body ...))
             (lambda () (%mlir::OpBuilder::~OpBuilder %builder))))]))

  ;; @brief with-RewritePatternSet — RAII for a heap-allocated RewritePatternSet.
  (define-syntax with-RewritePatternSet
    (syntax-rules ()
      [(_ (var) body ...)
       (with-raii (var (%mlir::RewritePatternSet::RewritePatternSet (current-MLIRContext))
                       %mlir::RewritePatternSet::~RewritePatternSet)
                  body ...)]
      [(_ (var ctx) body ...)
       (with-raii (var (%mlir::RewritePatternSet::RewritePatternSet ctx)
                       %mlir::RewritePatternSet::~RewritePatternSet)
                  body ...)]))

  ) ;; end library (mlir IR PatternMatch)

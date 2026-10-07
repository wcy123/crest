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
;; Also provides dynamic parameters and RAII macros for builder context.
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
    ;; Dynamic builder context
    current-RewriterBase
    current-OpBuilder
    ;; Context-dispatching constructor
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
          (mlir IR PatternMatch ffi)
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
                %mlir::OperationState::create
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

  ;; Dynamic builder context
  ;; @brief Active RewriterBase* uptr, or #f. Set by with-RewriterBase.
  (define current-RewriterBase (make-parameter #f))

  ;; @brief Active OpBuilder* uptr, or #f. Set by with-current-OpBuilder / with-OpBuilder.
  (define current-OpBuilder (make-parameter #f))

  ;; Pure Scheme helpers — compose raw C++ primitives.
  ;;
  ;; Insertion point is managed by the BUILDER's own state:
  ;;   - with-RewriterBase calls setInsertionPoint once at installation
  ;;   - After each create(), the builder advances its position naturally
  ;;   - No per-op setInsertionPoint needed; no current-InsertionPoint parameter
  ;;
  ;; Location for the OperationState:
  ;;   - 3/4-arg mlir-build-operation: mlir::UnknownLoc::get (debug info from #'op annotation)
  ;;   - 5-arg mlir-build-operation: explicit source-loc (mlir::FileLineColLoc from with-mlir-ops)

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
       [(rw source-loc name operands types)         (build rw source-loc name operands types 0)]
       [(rw source-loc name operands types nregions) (build rw source-loc name operands types nregions)])))

  (define op-builder-create-op
    (let ([build (lambda (b source-loc name operands types nregions)
                   (with-OperationState (state source-loc name)
                                        (for-each (lambda (v) (%mlir::OperationState::addOperands state v)) operands)
                                        (for-each (lambda (t) (%mlir::OperationState::addTypes state t)) types)
                                        (let loop ([i 0])
                                          (when (< i nregions)
                                            (%mlir::OperationState::addRegion state)
                                            (loop (+ i 1))))
                                        (%mlir::OpBuilder::create<OperationState> b state)))])
      (case-lambda
       [(b source-loc name operands types)         (build b source-loc name operands types 0)]
       [(b source-loc name operands types nregions) (build b source-loc name operands types nregions)])))

  ;; @brief Context-dispatching op constructor.
  ;; (name operands types)                    — UnknownLoc (builder manages insertion)
  ;; (name operands types nregions)           — same with regions
  ;; (name operands types source-loc nregions) — explicit mlir::Location from #'op annotation
  (define mlir-build-operation
    (let ([build (lambda (name operands types source-loc nregions)
                   (cond
                    [(current-RewriterBase) =>
                     (lambda (rw)
                       (rewriter-create-op rw source-loc name operands types nregions))]
                    [(current-OpBuilder) =>
                     (lambda (b)
                       (op-builder-create-op b source-loc name operands types nregions))]
                    [else (error 'mlir-build-operation "no current builder installed")]))]
          [default-nregions 0])
      (case-lambda
       [(name operands types)
        (build name operands types (mlir::UnknownLoc::get) default-nregions)]
       [(name operands types nregions)
        (build name operands types (mlir::UnknownLoc::get) nregions)]
       [(name operands types source-loc nregions)
        (build name operands types source-loc nregions)])))

  ;; @brief with-RewriterBase — install a RewriterBase and set its initial insertion point.
  ;; @param rw           RewriterBase* uptr (ConversionPatternRewriter or IRRewriter)
  ;; @param insert-point Operation* uptr — setInsertionPoint is called once here.
  ;;        After each op creation the builder advances its own position; no parameter tracks it.
  (define-syntax with-RewriterBase
    (syntax-rules ()
      [(_ (rw insert-point) body ...)
       (begin
         (mlir::RewriterBase::setInsertionPoint rw insert-point)
         (parameterize ([current-RewriterBase rw]
                        [current-OpBuilder    #f]
                        [current-MLIRContext  (mlir-Operation::getContext insert-point)])
           body ...))]))

  ;; @brief with-current-OpBuilder — install an existing OpBuilder*.
  ;; @param builder      OpBuilder* uptr — already positioned by caller
  ;; @param insert-point Operation* uptr — used only to derive current-MLIRContext
  (define-syntax with-current-OpBuilder
    (syntax-rules ()
      [(_ (builder insert-point) body ...)
       (parameterize ([current-OpBuilder  builder]
                      [current-RewriterBase #f]
                      [current-MLIRContext  (mlir-Operation::getContext insert-point)])
         body ...)]))

  ;; @brief with-OpBuilder — heap-allocate an OpBuilder at block end, run body, destroy.
  ;; @param block  Block* uptr — the builder is positioned at block->end() on creation
  (define-syntax with-OpBuilder
    (syntax-rules ()
      [(_ block body ...)
       (let ([%builder (%mlir::OpBuilder::atBlockEnd block)])
         (dynamic-wind
             (lambda () #f)
             (lambda ()
               (parameterize ([current-OpBuilder   %builder]
                              [current-RewriterBase #f]
                              [current-MLIRContext  (%mlir::OpBuilder::getContext %builder)])
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

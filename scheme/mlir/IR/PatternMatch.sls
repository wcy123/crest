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
;; Builder threading: the RewriterBase* is passed explicitly to
;; mlir-create-operation. The builder manages its own insertion point;
;; with-RewriterBase calls setInsertionPoint once at install.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR PatternMatch)
  (export
    ;; Clean-name re-exports from ffi
    mlir-create-operation
    mlir::RewriterBase::setInsertionPoint          ;; canonical: mlir::RewriterBase::setInsertionPoint(op)
    mlir::RewriterBase::setInsertionPoint-before   ;; backward-compat alias
    mlir::RewriterBase::setInsertionPoint-to-end
    mlir::RewriterBase::createBlock
    mlir::RewriterBase::replaceOp
    mlir::RewriterBase::eraseOp
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

  ;; @brief mlir::Operation::getContext — return the MLIRContext that owns this op.
  ;; @param op  Operation* uptr
  ;; @return    MLIRContext* uptr
  ;; @see       mlir/IR/Operation.h
  (define mlir-Operation::getContext mlir::Operation::getContext)

  ;; @brief mlir::RewriterBase::setInsertionPoint(op) — move IP to before op.
  ;; @param rewriter  RewriterBase* uptr
  ;; @param op        Operation* uptr
  ;; @see             mlir/IR/PatternMatch.h
  (define mlir::RewriterBase::setInsertionPoint       %mlir::RewriterBase::setInsertionPoint)
  (define mlir::RewriterBase::setInsertionPoint-before %mlir::RewriterBase::setInsertionPoint)

  ;; @brief mlir::RewriterBase::setInsertionPoint — move IP to end of block.
  ;; @param rewriter  RewriterBase* uptr
  ;; @param block     Block* uptr
  ;; @see             mlir/IR/PatternMatch.h
  (define mlir::RewriterBase::setInsertionPoint-to-end %mlir::RewriterBase::setInsertionPoint-to-end)

  ;; @brief mlir::RewriterBase::createBlock — append a new block to region.
  ;; @param rewriter  RewriterBase* uptr
  ;; @param region    Region* uptr
  ;; @return          Block* uptr
  ;; @see             mlir/IR/PatternMatch.h
  (define mlir::RewriterBase::createBlock             %mlir::RewriterBase::createBlock)

  ;; @brief mlir::RewriterBase::replaceOp — replace op with new values and erase it.
  ;; @param rewriter  RewriterBase* uptr
  ;; @param op        Operation* uptr — op to replace
  ;; @param new-op    Operation* uptr — replacement
  ;; @see             mlir/IR/PatternMatch.h
  (define mlir::RewriterBase::replaceOp               %mlir::RewriterBase::replaceOp)

  ;; @brief mlir::RewriterBase::eraseOp — erase op and all uses (must be dead).
  ;; @param rewriter  RewriterBase* uptr
  ;; @param op        Operation* uptr
  ;; @see             mlir/IR/PatternMatch.h
  (define mlir::RewriterBase::eraseOp                 %mlir::RewriterBase::eraseOp)

  ;; @brief Create an op via a RewriterBase*.
  ;; (rw name operands types)                     — UnknownLoc, 0 regions
  ;; (rw name operands types nregions)            — UnknownLoc, N regions
  ;; (rw name operands types source-loc nregions) — explicit mlir::Location
  ;;
  ;; NOTE: reinterpret_cast<OpBuilder*>(rwPtr) is UNSAFE — OpBuilder has no vtable
  ;; but RewriterBase introduces one, so the OpBuilder subobject sits at offset
  ;; +sizeof(vtable_ptr) within the RewriterBase object. Uses
  ;; %mlir::RewriterBase::create<OperationState> which casts to RewriterBase*.
  (define mlir-create-operation
    (let ([build (lambda (rw name operands types source-loc nregions)
                   (with-OperationState (state source-loc name)
                                        (for-each (lambda (v) (%mlir::OperationState::addOperands state v)) operands)
                                        (for-each (lambda (t) (%mlir::OperationState::addTypes state t)) types)
                                        (let loop ([i 0])
                                          (when (< i nregions)
                                            (%mlir::OperationState::addRegion state)
                                            (loop (+ i 1))))
                                        (%mlir::RewriterBase::create<OperationState> rw state)))])
      (case-lambda
       [(rw name operands types)
        (build rw name operands types (mlir::UnknownLoc::get) 0)]
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

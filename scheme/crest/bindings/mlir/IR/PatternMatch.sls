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
;; Also provides RAII macros.
;;
;; The pattern's rewriter is a CrestRef<RewriterBase> shell passed explicitly to
;; these bindings (replaceOp, eraseOp, setInsertionPoint, ...). To create ops with
;; the DSL or an OpBuilder binding, unwrap it with
;; (crest::as_ptr<mlir::OpBuilder> rw) from (mlir IR Builders).
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR PatternMatch)
  (export
    ;; Clean-name re-exports from ffi
    mlir-create-operation
    mlir::RewriterBase::setInsertionPoint
    mlir::RewriterBase::setInsertionPointToEnd
    mlir::RewriterBase::setInsertionPointToStart
    mlir::RewriterBase::createBlock
    mlir::RewriterBase::replaceOp
    mlir::RewriterBase::eraseOp
    mlir::RewriterBase::create<OperationState>
    mlir::RewritePatternSet::RewritePatternSet
    ;; Type predicates
    crest::isa<CrestBox<mlir::RewritePatternSet>>?
    ;; RAII macros
    with-RewritePatternSet)

  (import (rnrs)
          (only (mlir support CrestObject) with-CrestObject)
          (only (chezscheme) void)
          (only (mlir IR PatternMatch ffi)
                %mlir::RewriterBase::setInsertionPoint
                %mlir::RewriterBase::setInsertionPointToEnd
                %mlir::RewriterBase::setInsertionPointToStart
                %mlir::RewriterBase::createBlock
                %mlir::RewriterBase::replaceOp
                %mlir::RewriterBase::eraseOp
                %mlir::RewriterBase::create<OperationState>
                %mlir::RewritePatternSet::RewritePatternSet
                %crest::isa<CrestBox<mlir::RewritePatternSet>>)
          (only (mlir IR MLIRContext) current-MLIRContext)
          (only (mlir IR Location) mlir::UnknownLoc::get)
          (only (mlir IR Operation)
                mlir::Operation::getContext
                mlir::Operation::getLoc)
          (only (mlir IR OperationSupport)
                mlir::OperationState::addOperands
                mlir::OperationState::addTypes
                mlir::OperationState::addRegion
                with-OperationState))

  ;; @brief mlir::Operation::getContext — return the MLIRContext that owns this op.
  (define mlir-Operation::getContext mlir::Operation::getContext)

  ;; @brief mlir::RewriterBase::setInsertionPoint(op) — move IP to before op.
  (define mlir::RewriterBase::setInsertionPoint    %mlir::RewriterBase::setInsertionPoint)
  (define mlir::RewriterBase::setInsertionPointToEnd %mlir::RewriterBase::setInsertionPointToEnd)
  (define mlir::RewriterBase::setInsertionPointToStart %mlir::RewriterBase::setInsertionPointToStart)

  ;; @brief mlir::RewriterBase::createBlock — append a new block to region.
  (define mlir::RewriterBase::createBlock             %mlir::RewriterBase::createBlock)

  ;; @brief mlir::RewriterBase::replaceOp — replace op with new values and erase it.
  (define mlir::RewriterBase::replaceOp               %mlir::RewriterBase::replaceOp)

  ;; @brief mlir::RewriterBase::eraseOp — erase op and all uses (must be dead).
  (define mlir::RewriterBase::eraseOp                 %mlir::RewriterBase::eraseOp)

  (define mlir::RewriterBase::create<OperationState> %mlir::RewriterBase::create<OperationState>)
  (define mlir::RewritePatternSet::RewritePatternSet  %mlir::RewritePatternSet::RewritePatternSet)

  ;; @brief crest::isa<CrestBox<mlir::RewritePatternSet>>? — is this ptr a CrestBox<mlir::RewritePatternSet>?
  (define (crest::isa<CrestBox<mlir::RewritePatternSet>>? ptr)
    (not (zero? (%crest::isa<CrestBox<mlir::RewritePatternSet>> ptr))))

  ;; @brief Create an op via a RewriterBase*.
  ;; (rw name operands types)                     — UnknownLoc, 0 regions
  ;; (rw name operands types nregions)            — UnknownLoc, N regions
  ;; (rw name operands types source-loc nregions) — explicit mlir::Location
  ;;
  ;; NOTE: rw is a CrestRef<RewriterBase>*; %mlir::RewriterBase::create<OperationState>
  ;; extracts ->ptr internally. RewriterBase introduces the first vtable, so its
  ;; subobject offset differs from OpBuilder — these bindings are NOT interchangeable.
  (define mlir-create-operation
    (let ([build (lambda (rw name operands types source-loc nregions)
                   (with-OperationState state (source-loc name)
                     (for-each (lambda (v) (mlir::OperationState::addOperands state v)) operands)
                     (for-each (lambda (t) (mlir::OperationState::addTypes state t)) types)
                     (let loop ([i 0])
                       (when (< i nregions)
                         (mlir::OperationState::addRegion state)
                         (loop (+ i 1))))
                     (mlir::RewriterBase::create<OperationState> rw state)))])
      (case-lambda
       [(rw name operands types)
        (build rw name operands types (mlir::UnknownLoc::get) 0)]
       [(rw name operands types nregions)
        (build rw name operands types (mlir::UnknownLoc::get) nregions)]
       [(rw name operands types source-loc nregions)
        (build rw name operands types source-loc nregions)])))

  ;; @brief with-RewritePatternSet — RAII for a heap-allocated RewritePatternSet.
  ;; @note  Lifetime managed by CrestObject deletor; no explicit destructor needed.
  (define-syntax with-RewritePatternSet
    (syntax-rules ()
      [(_ var () body ...)
       (with-CrestObject var (mlir::RewritePatternSet::RewritePatternSet (current-MLIRContext))
         body ...)]
      [(_ var (ctx) body ...)
       (with-CrestObject var (mlir::RewritePatternSet::RewritePatternSet ctx)
         body ...)]))

  ) ;; end library (mlir IR PatternMatch)

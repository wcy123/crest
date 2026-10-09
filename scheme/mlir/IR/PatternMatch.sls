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
;; mlir-create-operation. Insertion point is set by the caller via
;; mlir::RewriterBase::setInsertionPoint before emitting ops.
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
    mlir::RewriterBase::create<OperationState>
    mlir::RewritePatternSet::RewritePatternSet
    ;; Type predicates
    crest::isa<CrestRef<mlir::RewriterBase>>?
    crest::isa<CrestOwned<mlir::RewritePatternSet>>?
    ;; RAII macros
    with-raii
    with-RewritePatternSet)

  (import (rnrs)
          (only (mlir support RAII) with-raii)
          (only (mlir support array-ref) with-CrestObject)
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
                %crest::isa<CrestOwned<mlir::RewritePatternSet>>
                %crest::isa<CrestRef<mlir::RewriterBase>>)
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
  (define mlir::RewriterBase::setInsertionPoint       %mlir::RewriterBase::setInsertionPoint)
  (define mlir::RewriterBase::setInsertionPoint-before %mlir::RewriterBase::setInsertionPoint)

  ;; @brief mlir::RewriterBase::setInsertionPoint — move IP to end of block.
  (define mlir::RewriterBase::setInsertionPoint-to-end %mlir::RewriterBase::setInsertionPoint-to-end)

  ;; @brief mlir::RewriterBase::createBlock — append a new block to region.
  (define mlir::RewriterBase::createBlock             %mlir::RewriterBase::createBlock)

  ;; @brief mlir::RewriterBase::replaceOp — replace op with new values and erase it.
  (define mlir::RewriterBase::replaceOp               %mlir::RewriterBase::replaceOp)

  ;; @brief mlir::RewriterBase::eraseOp — erase op and all uses (must be dead).
  (define mlir::RewriterBase::eraseOp                 %mlir::RewriterBase::eraseOp)

  (define mlir::RewriterBase::create<OperationState> %mlir::RewriterBase::create<OperationState>)
  (define mlir::RewritePatternSet::RewritePatternSet  %mlir::RewritePatternSet::RewritePatternSet)

  ;; @brief crest::isa<CrestRef<mlir::RewriterBase>>? — is this ptr a CrestRef<mlir::RewriterBase>?
  (define (crest::isa<CrestRef<mlir::RewriterBase>>? ptr)
    (not (zero? (%crest::isa<CrestRef<mlir::RewriterBase>> ptr))))

  ;; @brief crest::isa<CrestOwned<mlir::RewritePatternSet>>? — is this ptr a CrestOwned<mlir::RewritePatternSet>?
  (define (crest::isa<CrestOwned<mlir::RewritePatternSet>>? ptr)
    (not (zero? (%crest::isa<CrestOwned<mlir::RewritePatternSet>> ptr))))

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
                   (with-OperationState (state source-loc name)
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
      [(_ (var) body ...)
       (with-CrestObject (var (mlir::RewritePatternSet::RewritePatternSet (current-MLIRContext)))
                         body ...)]
      [(_ (var ctx) body ...)
       (with-CrestObject (var (mlir::RewritePatternSet::RewritePatternSet ctx))
                         body ...)]))

  ) ;; end library (mlir IR PatternMatch)

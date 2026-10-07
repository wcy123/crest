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
    rewriter-create-op-with-regions
    mlir::RewriterBase::setInsertionPoint          ;; canonical: mlir::RewriterBase::setInsertionPoint(op)
    mlir::RewriterBase::setInsertionPoint-before   ;; backward-compat alias
    mlir::RewriterBase::setInsertionPoint-to-end
    mlir::RewriterBase::createBlock
    mlir::RewriterBase::replaceOp
    mlir::RewriterBase::eraseOp
    crest::RewriterBase::cloneWithTypes
    ;; Dynamic builder context
    current-RewriterBase
    current-OpBuilder
    ;; current-InsertionPoint is intentionally NOT exported —
    ;; it must only be set via with-RewriterBase / with-current-OpBuilder
    ;; to ensure it stays consistent with the active builder.
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
          (mlir IR Builders ffi)
          (only (mlir IR MLIRContext) current-MLIRContext)
          (only (mlir IR Location) mlir::UnknownLoc::get)
          (only (mlir IR Operation) mlir::Operation::getContext mlir::Operation::getLoc)
          (only (mlir IR OperationSupport)
                %mlir::OperationState::create
                %mlir::OperationState::addOperands
                %mlir::OperationState::addTypes
                %mlir::OperationState::addRegion
                %mlir::OperationState::~OperationState
                with-OperationState))

  (define mlir-Operation::getContext mlir::Operation::getContext)

  ;; @brief mlir::RewriterBase::setInsertionPoint(op) — move the rewriter's insertion point to before op.
  (define mlir::RewriterBase::setInsertionPoint       %mlir::RewriterBase::setInsertionPoint)
  ;; @brief Backward-compat alias for mlir::RewriterBase::setInsertionPoint.
  (define mlir::RewriterBase::setInsertionPoint-before %mlir::RewriterBase::setInsertionPoint)
  ;; @brief mlir::RewriterBase::setInsertionPointToEnd(block)
  (define mlir::RewriterBase::setInsertionPoint-to-end %mlir::RewriterBase::setInsertionPoint-to-end)
  ;; @brief mlir::RewriterBase::createBlock(region)
  (define mlir::RewriterBase::createBlock             %mlir::RewriterBase::createBlock)
  ;; @brief mlir::RewriterBase::replaceOp
  (define mlir::RewriterBase::replaceOp               %mlir::RewriterBase::replaceOp)
  ;; @brief mlir::RewriterBase::eraseOp
  (define mlir::RewriterBase::eraseOp                 %mlir::RewriterBase::eraseOp)
  ;; @brief Clone op with new operands/types, copying attributes.
  (define crest::RewriterBase::cloneWithTypes         %crest::RewriterBase::cloneWithTypes)

  ;; Dynamic builder context
  ;; @brief Active RewriterBase* uptr, or #f. Set by with-RewriterBase.
  (define current-RewriterBase (make-parameter #f))

  ;; @brief Active OpBuilder* uptr, or #f. Set by with-current-OpBuilder / with-OpBuilder.
  (define current-OpBuilder (make-parameter #f))

  ;; Internal: insertion-point Operation* uptr. Always set alongside the builder via
  ;; with-RewriterBase or with-current-OpBuilder — never set independently.
  (define current-InsertionPoint (make-parameter #f))

  ;; Pure Scheme helpers — compose raw C++ primitives.
  ;; rewriter-create-op* variants take an explicit mlir::Location (source annotation).
  ;; rewriter-create-op variants derive location from the insertion-point Operation*.

  (define (rewriter-create-op rw insert-point name operands types)
    (mlir::RewriterBase::setInsertionPoint rw insert-point)
    (with-OperationState (state (mlir::Operation::getLoc insert-point) name)
                         (for-each (lambda (v) (%mlir::OperationState::addOperands state v)) operands)
                         (for-each (lambda (t) (%mlir::OperationState::addTypes state t)) types)
                         (%mlir::RewriterBase::create<OperationState> rw state)))

  (define (rewriter-create-op-with-regions rw insert-point name operands types nregions)
    (mlir::RewriterBase::setInsertionPoint rw insert-point)
    (with-OperationState (state (mlir::Operation::getLoc insert-point) name)
                         (for-each (lambda (v) (%mlir::OperationState::addOperands state v)) operands)
                         (for-each (lambda (t) (%mlir::OperationState::addTypes state t)) types)
                         (let loop ([i 0])
                           (when (< i nregions)
                             (%mlir::OperationState::addRegion state)
                             (loop (+ i 1))))
                         (%mlir::RewriterBase::create<OperationState> rw state)))

  (define (op-builder-create-op b insert-point name operands types)
    (with-OperationState (state (mlir::Operation::getLoc insert-point) name)
                         (for-each (lambda (v) (%mlir::OperationState::addOperands state v)) operands)
                         (for-each (lambda (t) (%mlir::OperationState::addTypes state t)) types)
                         (%mlir::OpBuilder::create<OperationState> b state)))

  (define (op-builder-create-op-with-regions b insert-point name operands types nregions)
    (with-OperationState (state (mlir::Operation::getLoc insert-point) name)
                         (for-each (lambda (v) (%mlir::OperationState::addOperands state v)) operands)
                         (for-each (lambda (t) (%mlir::OperationState::addTypes state t)) types)
                         (let loop ([i 0])
                           (when (< i nregions)
                             (%mlir::OperationState::addRegion state)
                             (loop (+ i 1))))
                         (%mlir::OpBuilder::create<OperationState> b state)))

  ;; Variants with explicit mlir::Location (source-loc from syntax annotation).
  (define (rewriter-create-op* rw insert-point source-loc name operands types)
    (mlir::RewriterBase::setInsertionPoint rw insert-point)
    (with-OperationState (state source-loc name)
                         (for-each (lambda (v) (%mlir::OperationState::addOperands state v)) operands)
                         (for-each (lambda (t) (%mlir::OperationState::addTypes state t)) types)
                         (%mlir::RewriterBase::create<OperationState> rw state)))

  (define (rewriter-create-op*-with-regions rw insert-point source-loc name operands types nregions)
    (mlir::RewriterBase::setInsertionPoint rw insert-point)
    (with-OperationState (state source-loc name)
                         (for-each (lambda (v) (%mlir::OperationState::addOperands state v)) operands)
                         (for-each (lambda (t) (%mlir::OperationState::addTypes state t)) types)
                         (let loop ([i 0])
                           (when (< i nregions)
                             (%mlir::OperationState::addRegion state)
                             (loop (+ i 1))))
                         (%mlir::RewriterBase::create<OperationState> rw state)))

  (define (op-builder-create-op* b source-loc name operands types)
    (with-OperationState (state source-loc name)
                         (for-each (lambda (v) (%mlir::OperationState::addOperands state v)) operands)
                         (for-each (lambda (t) (%mlir::OperationState::addTypes state t)) types)
                         (%mlir::OpBuilder::create<OperationState> b state)))

  (define (op-builder-create-op*-with-regions b source-loc name operands types nregions)
    (with-OperationState (state source-loc name)
                         (for-each (lambda (v) (%mlir::OperationState::addOperands state v)) operands)
                         (for-each (lambda (t) (%mlir::OperationState::addTypes state t)) types)
                         (let loop ([i 0])
                           (when (< i nregions)
                             (%mlir::OperationState::addRegion state)
                             (loop (+ i 1))))
                         (%mlir::OpBuilder::create<OperationState> b state)))

  ;; @brief Context-dispatching op constructor.
  ;; (name operands types)              — uses current-InsertionPoint as insert-point
  ;; (name operands types nregions)     — same, with regions
  ;; (name operands types source-loc nregions) — explicit mlir::Location from #'op annotation
  (define mlir-build-operation
    (let ([build (lambda (name operands types insert-point nregions)
                   (cond
                    [(current-RewriterBase) =>
                     (lambda (rw)
                       (if (zero? nregions)
                           (rewriter-create-op rw insert-point name operands types)
                           (rewriter-create-op-with-regions rw insert-point name operands types nregions)))]
                    [(current-OpBuilder) =>
                     (lambda (b)
                       (if (zero? nregions)
                           (op-builder-create-op b insert-point name operands types)
                           (op-builder-create-op-with-regions b insert-point name operands types nregions)))]
                    [else (error 'mlir-build-operation "no current builder installed")]))]
          [default-nregions 0])
      (case-lambda
       [(name operands types)
        (build name operands types (current-InsertionPoint) default-nregions)]
       [(name operands types nregions)
        (build name operands types (current-InsertionPoint) nregions)]
       [(name operands types source-loc nregions)
        ;; source-loc is a mlir::Location uptr — use explicit insert-point and source-loc separately
        (let ([ip (current-InsertionPoint)])
          (cond
           [(current-RewriterBase) =>
            (lambda (rw)
              (if (zero? nregions)
                  (rewriter-create-op* rw ip source-loc name operands types)
                  (rewriter-create-op*-with-regions rw ip source-loc name operands types nregions)))]
           [(current-OpBuilder) =>
            (lambda (b)
              (if (zero? nregions)
                  (op-builder-create-op* b source-loc name operands types)
                  (op-builder-create-op*-with-regions b source-loc name operands types nregions)))]
           [else (error 'mlir-build-operation "no current builder installed")]))])))

  ;; @brief with-RewriterBase — install a RewriterBase as the active builder.
  ;; @param rw           RewriterBase* uptr
  ;; @param insert-point Operation* uptr — the insertion anchor.
  ;;        Sets current-InsertionPoint; each op creation calls setInsertionPoint(rw, insert-point)
  ;;        to insert before this op. Must not be set independently of the builder.
  (define-syntax with-RewriterBase
    (syntax-rules ()
      [(_ (rw insert-point) body ...)
       (parameterize ([current-RewriterBase    rw]
                      [current-OpBuilder       #f]
                      [current-InsertionPoint  insert-point]
                      [current-MLIRContext     (mlir-Operation::getContext insert-point)])
         body ...)]))

  ;; @brief with-current-OpBuilder — install an existing OpBuilder*.
  ;; @param builder      OpBuilder* uptr
  ;; @param insert-point Operation* uptr — insertion anchor and MLIRContext source.
  (define-syntax with-current-OpBuilder
    (syntax-rules ()
      [(_ (builder insert-point) body ...)
       (parameterize ([current-OpBuilder      builder]
                      [current-RewriterBase   #f]
                      [current-InsertionPoint insert-point]
                      [current-MLIRContext    (mlir-Operation::getContext insert-point)])
         body ...)]))

  ;; @brief with-OpBuilder — heap-allocate an OpBuilder at block end, run body, destroy.
  (define-syntax with-OpBuilder
    (syntax-rules ()
      [(_ block body ...)
       (let ([%builder (%mlir::OpBuilder::atBlockEnd block)])
         (dynamic-wind
             (lambda () #f)
             (lambda ()
               (parameterize ([current-OpBuilder   %builder]
                              [current-RewriterBase #f])
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

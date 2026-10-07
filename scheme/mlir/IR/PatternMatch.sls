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
    mlir::RewriterBase::create
    mlir::RewriterBase::create-with-regions
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
    current-Location
    ;; Context-dispatching constructor
    mlir-build-operation
    ;; RAII macros
    with-raii
    with-RewritePatternSet
    with-RewriterBase
    with-current-OpBuilder
    with-OpBuilder
    with-Location)

  (import (rnrs)
          (only (mlir support RAII) with-raii)
          (only (chezscheme) make-parameter parameterize void)
          (mlir IR PatternMatch ffi)
          (mlir IR Builders ffi)
          (only (mlir IR MLIRContext) current-MLIRContext)
          (only (mlir IR Operation) mlir::Operation::getContext))

  (define mlir-Operation::getContext mlir::Operation::getContext)

  ;; @brief mlir::RewriterBase::create — create an op via OperationState, setting insertion point before loc-op.
  ;; @param rewriter      RewriterBase* uptr (ConversionPatternRewriter or IRRewriter)
  ;; @param loc-op        Operation* uptr — insertion point and location source
  ;; @param op-name       Registered MLIR op name string (e.g. "arith.addi")
  ;; @param operands      Scheme list of Value* uptrs
  ;; @param result-types  Scheme list of Type* uptrs
  ;; @return              Operation* uptr of the created op, or 0 on bad input
  ;; @see                 mlir/IR/PatternMatch.h
  ;; @note                Defined in lib/Bindings/IR/RewriterBase.cpp
  (define mlir::RewriterBase::create                   %mlir::RewriterBase::create)

  ;; @brief mlir::RewriterBase::create — create an op with pre-allocated empty regions, setting insertion point before loc-op.
  ;; @param rewriter      RewriterBase* uptr
  ;; @param loc-op        Operation* uptr — insertion point and location source
  ;; @param op-name       Registered MLIR op name string
  ;; @param operands      Scheme list of Value* uptrs
  ;; @param result-types  Scheme list of Type* uptrs
  ;; @param num-regions   Number of empty regions to pre-allocate (int)
  ;; @return              Operation* uptr of the created op, or 0 on bad input
  ;; @see                 mlir/IR/PatternMatch.h
  ;; @note                Defined in lib/Bindings/IR/RewriterBase.cpp
  (define mlir::RewriterBase::create-with-regions      %mlir::RewriterBase::create-with-regions)

  ;; @brief mlir::RewriterBase::setInsertionPoint(op) — move the rewriter's insertion point to before op.
  ;; @param rewriter  RewriterBase* uptr
  ;; @param op        Operation* uptr — target operation
  ;; @return          void
  ;; @see             mlir/IR/PatternMatch.h, mlir/IR/Builders.h
  ;; @note            Defined in lib/Bindings/IR/RewriterBase.cpp
  (define mlir::RewriterBase::setInsertionPoint       %mlir::RewriterBase::setInsertionPoint)

  ;; @brief Backward-compat alias for mlir::RewriterBase::setInsertionPoint.
  (define mlir::RewriterBase::setInsertionPoint-before %mlir::RewriterBase::setInsertionPoint)

  ;; @brief mlir::RewriterBase::setInsertionPointToEnd(block) — move the rewriter's insertion point to the end of block.
  ;; @param rewriter  RewriterBase* uptr
  ;; @param block     Block* uptr — target block
  ;; @return          void
  ;; @see             mlir/IR/PatternMatch.h
  ;; @note            Defined in lib/Bindings/IR/RewriterBase.cpp
  (define mlir::RewriterBase::setInsertionPoint-to-end %mlir::RewriterBase::setInsertionPoint-to-end)

  ;; @brief mlir::RewriterBase::createBlock(region) — create a new block in region, add typed arguments, set insertion point to end.
  ;; @param rewriter       RewriterBase* uptr
  ;; @param region         Region* uptr — target region
  ;; @param arg-types      Scheme list of Type* uptrs for block arguments (may be '())
  ;; @return               Block* uptr of the newly created block, or 0 on bad input
  ;; @see                  mlir/IR/PatternMatch.h
  ;; @note                 Defined in lib/Bindings/IR/RewriterBase.cpp; sets insertion point to end of new block
  (define mlir::RewriterBase::createBlock             %mlir::RewriterBase::createBlock)

  ;; @brief mlir::RewriterBase::replaceOp — replace old-op with a single new Value.
  ;; @param rewriter   RewriterBase* uptr
  ;; @param old-op     Operation* uptr — op to replace and erase
  ;; @param new-value  Value* uptr — replacement value
  ;; @return           1 on success, 0 if rewriter is null
  ;; @see              mlir/IR/PatternMatch.h
  ;; @note             Defined in lib/Bindings/IR/RewriterBase.cpp
  (define mlir::RewriterBase::replaceOp               %mlir::RewriterBase::replaceOp)

  ;; @brief mlir::RewriterBase::eraseOp — erase op from its parent block (op must have no uses).
  ;; @param rewriter  RewriterBase* uptr
  ;; @param op        Operation* uptr — op to erase
  ;; @return          1 on success, 0 if rewriter is null
  ;; @see             mlir/IR/PatternMatch.h
  ;; @note            Defined in lib/Bindings/IR/RewriterBase.cpp
  (define mlir::RewriterBase::eraseOp                 %mlir::RewriterBase::eraseOp)

  ;; @brief Clone op with new operands and result types, copying all attributes, then create via the rewriter.
  ;; @param rewriter      RewriterBase* uptr
  ;; @param op            Operation* uptr — template op (name and attributes are copied)
  ;; @param operands      Scheme list of Value* uptrs — new operand values
  ;; @param result-types  Scheme list of Type* uptrs — new result types
  ;; @return              Operation* uptr of the cloned op, or 0 on bad input
  ;; @see                 mlir/IR/PatternMatch.h
  ;; @note                Defined in lib/Bindings/IR/RewriterBase.cpp; uses op location for the new OperationState
  (define crest::RewriterBase::cloneWithTypes         %crest::RewriterBase::cloneWithTypes)

  ;; Dynamic builder context
  ;; @brief Dynamic parameter holding the active RewriterBase* uptr, or #f when none is installed.
  ;; @note  Set by with-RewriterBase; cleared to #f by with-current-OpBuilder.
  (define current-RewriterBase      (make-parameter #f))

  ;; @brief Dynamic parameter holding the active OpBuilder* uptr, or #f when none is installed.
  ;; @note  Set by with-current-OpBuilder / with-OpBuilder; cleared to #f by with-RewriterBase.
  (define current-OpBuilder (make-parameter #f))

  ;; @brief Dynamic parameter holding the current location Operation* uptr used by mlir-build-operation.
  ;; @note  Set by with-RewriterBase, with-current-OpBuilder, and with-Location.
  (define current-Location           (make-parameter #f))

  ;; @brief Context-dispatching op constructor — build an op using whichever builder is currently active.
  ;; @param name       Registered MLIR op name string (e.g. "arith.addi")
  ;; @param operands   Scheme list of Value* uptrs
  ;; @param types      Scheme list of Type* uptrs (result types)
  ;; @param rest       Optional single integer: number of regions to pre-allocate (default 0)
  ;; @return           Operation* uptr of the created op
  ;; @note             Dispatches to current-RewriterBase if set, else current-OpBuilder.
  ;;                   Raises an error if neither is installed.
  (define mlir-build-operation
    (let ([build (lambda (name operands types nregions)
                   (let ([loc (current-Location)])
                     (cond
                      [(current-RewriterBase) =>
                       (lambda (rw)
                         (if (zero? nregions)
                             (%mlir::RewriterBase::create rw loc name operands types)
                             (%mlir::RewriterBase::create-with-regions rw loc name operands types nregions)))]
                      [(current-OpBuilder) =>
                       (lambda (b)
                         (if (zero? nregions)
                             (%mlir::OpBuilder::create b loc name operands types)
                             (%mlir::OpBuilder::create-with-regions b loc name operands types nregions)))]
                      [else (error 'mlir-build-operation "no current builder installed")])))]
          [default-nregions 0])
      (case-lambda
       [(name operands types)          (build name operands types default-nregions)]
       [(name operands types nregions) (build name operands types nregions)])))

  ;; @brief RAII macro — install a RewriterBase as the active builder for the dynamic extent of body.
  ;; @param rw    RewriterBase* uptr (ConversionPatternRewriter or IRRewriter)
  ;; @param loc   Operation* uptr — location source; also used to derive current-MLIRContext
  ;; @return      Value of the last body expression
  ;; @note        Sets current-RewriterBase to rw and clears current-OpBuilder to #f.
  ;;              current-MLIRContext is derived from loc via mlir-Operation::getContext.
  ;;              Nested with-RewriterBase or with-current-OpBuilder forms shadow these bindings.
  (define-syntax with-RewriterBase
    (syntax-rules ()
      [(_ (rw loc) body ...)
       (parameterize ([current-RewriterBase      rw]
                      [current-OpBuilder #f]
                      [current-Location           loc]
                      [current-MLIRContext  (mlir-Operation::getContext loc)])
         body ...)]))

  ;; @brief Install an existing OpBuilder* as the active block builder for the dynamic extent of body.
  ;; @param builder  OpBuilder* uptr — already-positioned builder (caller owns lifetime)
  ;; @param loc      Operation* uptr — location source; also used to derive current-MLIRContext
  ;; @return         Value of the last body expression
  ;; @note           Sets current-OpBuilder to builder and clears current-RewriterBase to #f.
  ;;                 Prefer with-OpBuilder when you want automatic builder lifetime management.
  (define-syntax with-current-OpBuilder
    (syntax-rules ()
      [(_ (builder loc) body ...)
       (parameterize ([current-OpBuilder builder]
                      [current-RewriterBase      #f]
                      [current-Location           loc]
                      [current-MLIRContext  (mlir-Operation::getContext loc)])
         body ...)]))

  ;; @brief RAII macro — heap-allocate an OpBuilder at the end of block, run body, then destroy the builder.
  ;; @param block  Block* uptr — target block; the builder is positioned at block->end()
  ;; @return       Value of the last body expression
  ;; @note         Allocates an OpBuilder via %mlir::OpBuilder::atBlockEnd and frees it with
  ;;               %mlir::OpBuilder::~OpBuilder on exit (even via non-local exit).
  ;;               Sets current-OpBuilder and clears current-RewriterBase to #f.
  ;;               Does NOT update current-Location or current-MLIRContext; use with-Location if needed.
  (define-syntax with-OpBuilder
    (syntax-rules ()
      [(_ block body ...)
       (let ([%builder (%mlir::OpBuilder::atBlockEnd block)])
         (dynamic-wind
             (lambda () #f)
             (lambda ()
               (parameterize ([current-OpBuilder %builder]
                              [current-RewriterBase #f])
                 body ...))
             (lambda () (%mlir::OpBuilder::~OpBuilder %builder))))]))

  ;; @brief Override current-Location for the dynamic extent of body without changing the active builder.
  ;; @param loc   Operation* uptr — new location source for mlir-build-operation
  ;; @return      Value of the last body expression
  ;; @note        Only rebinds current-Location; current-RewriterBase and current-OpBuilder are unchanged.
  ;;              Useful when emitting ops that should carry a location different from the builder's default.
  (define-syntax with-Location
    (syntax-rules ()
      [(_ loc body ...)
       (parameterize ([current-Location loc]) body ...)]))

  ;; @brief with-RewritePatternSet — RAII for a heap-allocated RewritePatternSet.
  ;; @param var  identifier bound to the RewritePatternSet* uptr for BODY
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-MLIRContext)
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

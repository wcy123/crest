#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir rewriter-base) — RewriterBase user-visible API.
;;
;; Mirrors mlir/IR/PatternMatch.h RewriterBase.
;; Re-exports clean names from (mlir ir rewriter-base ffi).
;; Also provides dynamic parameters and RAII macros for builder context.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir rewriter-base)
  (export
    ;; Clean-name re-exports from ffi
    rewriter-base-create
    rewriter-base-create-with-regions
    rewriter-base-set-insertion-point-before
    rewriter-base-set-insertion-point-to-end
    rewriter-base-create-block
    rewriter-base-replace-op
    rewriter-base-erase-op
    rewriter-base-clone-with-types
    ;; Dynamic builder context
    current-rewriter
    current-block-builder
    current-loc
    ;; Context-dispatching constructor
    mlir-build-operation
    ;; RAII macros
    with-raii
    with-rewrite-builder
    with-current-block-builder
    with-block-builder
    with-op-location)

  (import (rnrs)
          (only (chezscheme) make-parameter parameterize void)
          (mlir ir rewriter-base ffi)
          (mlir ir op-builder ffi)
          (only (mlir ir mlir-context) current-mlir-context)
          (only (mlir core operation) mlir-operation-get-context))

  ;; @brief mlir::RewriterBase::create — create an op via OperationState, setting insertion point before loc-op.
  ;; @param rewriter      RewriterBase* uptr (ConversionPatternRewriter or IRRewriter)
  ;; @param loc-op        Operation* uptr — insertion point and location source
  ;; @param op-name       Registered MLIR op name string (e.g. "arith.addi")
  ;; @param operands      Scheme list of Value* uptrs
  ;; @param result-types  Scheme list of Type* uptrs
  ;; @return              Operation* uptr of the created op, or 0 on bad input
  ;; @see                 mlir/IR/PatternMatch.h
  ;; @note                Defined in lib/Bindings/IR/RewriterBase.cpp
  (define rewriter-base-create                   %rewriter-base-create)

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
  (define rewriter-base-create-with-regions      %rewriter-base-create-with-regions)

  ;; @brief mlir::RewriterBase::setInsertionPoint(op) — move the rewriter's insertion point to before op.
  ;; @param rewriter  RewriterBase* uptr
  ;; @param op        Operation* uptr — target operation
  ;; @return          void
  ;; @see             mlir/IR/PatternMatch.h
  ;; @note            Defined in lib/Bindings/IR/RewriterBase.cpp
  (define rewriter-base-set-insertion-point-before %rewriter-base-set-insertion-point-before)

  ;; @brief mlir::RewriterBase::setInsertionPointToEnd(block) — move the rewriter's insertion point to the end of block.
  ;; @param rewriter  RewriterBase* uptr
  ;; @param block     Block* uptr — target block
  ;; @return          void
  ;; @see             mlir/IR/PatternMatch.h
  ;; @note            Defined in lib/Bindings/IR/RewriterBase.cpp
  (define rewriter-base-set-insertion-point-to-end %rewriter-base-set-insertion-point-to-end)

  ;; @brief mlir::RewriterBase::createBlock(region) — create a new block in region, add typed arguments, set insertion point to end.
  ;; @param rewriter       RewriterBase* uptr
  ;; @param region         Region* uptr — target region
  ;; @param arg-types      Scheme list of Type* uptrs for block arguments (may be '())
  ;; @return               Block* uptr of the newly created block, or 0 on bad input
  ;; @see                  mlir/IR/PatternMatch.h
  ;; @note                 Defined in lib/Bindings/IR/RewriterBase.cpp; sets insertion point to end of new block
  (define rewriter-base-create-block             %rewriter-base-create-block)

  ;; @brief mlir::RewriterBase::replaceOp — replace old-op with a single new Value.
  ;; @param rewriter   RewriterBase* uptr
  ;; @param old-op     Operation* uptr — op to replace and erase
  ;; @param new-value  Value* uptr — replacement value
  ;; @return           1 on success, 0 if rewriter is null
  ;; @see              mlir/IR/PatternMatch.h
  ;; @note             Defined in lib/Bindings/IR/RewriterBase.cpp
  (define rewriter-base-replace-op               %rewriter-base-replace-op)

  ;; @brief mlir::RewriterBase::eraseOp — erase op from its parent block (op must have no uses).
  ;; @param rewriter  RewriterBase* uptr
  ;; @param op        Operation* uptr — op to erase
  ;; @return          1 on success, 0 if rewriter is null
  ;; @see             mlir/IR/PatternMatch.h
  ;; @note            Defined in lib/Bindings/IR/RewriterBase.cpp
  (define rewriter-base-erase-op                 %rewriter-base-erase-op)

  ;; @brief Clone op with new operands and result types, copying all attributes, then create via the rewriter.
  ;; @param rewriter      RewriterBase* uptr
  ;; @param op            Operation* uptr — template op (name and attributes are copied)
  ;; @param operands      Scheme list of Value* uptrs — new operand values
  ;; @param result-types  Scheme list of Type* uptrs — new result types
  ;; @return              Operation* uptr of the cloned op, or 0 on bad input
  ;; @see                 mlir/IR/PatternMatch.h
  ;; @note                Defined in lib/Bindings/IR/RewriterBase.cpp; uses op location for the new OperationState
  (define rewriter-base-clone-with-types         %rewriter-base-clone-with-types)

  ;; Dynamic builder context
  ;; @brief Dynamic parameter holding the active RewriterBase* uptr, or #f when none is installed.
  ;; @note  Set by with-rewrite-builder; cleared to #f by with-current-block-builder.
  (define current-rewriter      (make-parameter #f))

  ;; @brief Dynamic parameter holding the active OpBuilder* uptr, or #f when none is installed.
  ;; @note  Set by with-current-block-builder / with-block-builder; cleared to #f by with-rewrite-builder.
  (define current-block-builder (make-parameter #f))

  ;; @brief Dynamic parameter holding the current location Operation* uptr used by mlir-build-operation.
  ;; @note  Set by with-rewrite-builder, with-current-block-builder, and with-op-location.
  (define current-loc           (make-parameter #f))

  ;; @brief Context-dispatching op constructor — build an op using whichever builder is currently active.
  ;; @param name       Registered MLIR op name string (e.g. "arith.addi")
  ;; @param operands   Scheme list of Value* uptrs
  ;; @param types      Scheme list of Type* uptrs (result types)
  ;; @param rest       Optional single integer: number of regions to pre-allocate (default 0)
  ;; @return           Operation* uptr of the created op
  ;; @note             Dispatches to current-rewriter if set, else current-block-builder.
  ;;                   Raises an error if neither is installed.
  (define (mlir-build-operation name operands types . rest)
    (let ([nregions (if (pair? rest) (car rest) 0)]
          [loc      (current-loc)])
      (cond
        [(current-rewriter) =>
         (lambda (rw)
           (if (zero? nregions)
               (%rewriter-base-create rw loc name operands types)
               (%rewriter-base-create-with-regions rw loc name operands types nregions)))]
        [(current-block-builder) =>
         (lambda (b)
           (if (zero? nregions)
               (%op-builder-create b loc name operands types)
               (%op-builder-create-with-regions b loc name operands types nregions)))]
        [else (error 'mlir-build-operation "no current builder installed")])))

  ;; @brief RAII macro — acquire a resource, run body forms, then unconditionally release it.
  ;; @param var   Binding name for the acquired resource
  ;; @param ctor  Expression that produces the resource (called once before body)
  ;; @param dtor  Procedure of one argument called with var after body, even on non-local exit
  ;; @return      Value of the last body expression
  ;; @note        Implemented with dynamic-wind so the destructor runs on continuations and exceptions.
  (define-syntax with-raii
    (syntax-rules ()
      [(_ (var ctor dtor) body ...)
       (let ([var ctor])
         (dynamic-wind void
           (lambda () body ...)
           (lambda () (dtor var))))]))

  ;; @brief RAII macro — install a RewriterBase as the active builder for the dynamic extent of body.
  ;; @param rw    RewriterBase* uptr (ConversionPatternRewriter or IRRewriter)
  ;; @param loc   Operation* uptr — location source; also used to derive current-mlir-context
  ;; @return      Value of the last body expression
  ;; @note        Sets current-rewriter to rw and clears current-block-builder to #f.
  ;;              current-mlir-context is derived from loc via mlir-operation-get-context.
  ;;              Nested with-rewrite-builder or with-current-block-builder forms shadow these bindings.
  (define-syntax with-rewrite-builder
    (syntax-rules ()
      [(_ (rw loc) body ...)
       (parameterize ([current-rewriter      rw]
                      [current-block-builder #f]
                      [current-loc           loc]
                      [current-mlir-context  (mlir-operation-get-context loc)])
         body ...)]))

  ;; @brief Install an existing OpBuilder* as the active block builder for the dynamic extent of body.
  ;; @param builder  OpBuilder* uptr — already-positioned builder (caller owns lifetime)
  ;; @param loc      Operation* uptr — location source; also used to derive current-mlir-context
  ;; @return         Value of the last body expression
  ;; @note           Sets current-block-builder to builder and clears current-rewriter to #f.
  ;;                 Prefer with-block-builder when you want automatic builder lifetime management.
  (define-syntax with-current-block-builder
    (syntax-rules ()
      [(_ (builder loc) body ...)
       (parameterize ([current-block-builder builder]
                      [current-rewriter      #f]
                      [current-loc           loc]
                      [current-mlir-context  (mlir-operation-get-context loc)])
         body ...)]))

  ;; @brief RAII macro — heap-allocate an OpBuilder at the end of block, run body, then destroy the builder.
  ;; @param block  Block* uptr — target block; the builder is positioned at block->end()
  ;; @return       Value of the last body expression
  ;; @note         Allocates an OpBuilder via %op-builder-at-block-end and frees it with
  ;;               %op-builder-destroy on exit (even via non-local exit).
  ;;               Sets current-block-builder and clears current-rewriter to #f.
  ;;               Does NOT update current-loc or current-mlir-context; use with-op-location if needed.
  (define-syntax with-block-builder
    (syntax-rules ()
      [(_ block body ...)
       (let ([%builder (%op-builder-at-block-end block)])
         (dynamic-wind
           (lambda () #f)
           (lambda ()
             (parameterize ([current-block-builder %builder]
                            [current-rewriter #f])
               body ...))
           (lambda () (%op-builder-destroy %builder))))]))

  ;; @brief Override current-loc for the dynamic extent of body without changing the active builder.
  ;; @param loc   Operation* uptr — new location source for mlir-build-operation
  ;; @return      Value of the last body expression
  ;; @note        Only rebinds current-loc; current-rewriter and current-block-builder are unchanged.
  ;;              Useful when emitting ops that should carry a location different from the builder's default.
  (define-syntax with-op-location
    (syntax-rules ()
      [(_ loc body ...)
       (parameterize ([current-loc loc]) body ...)]))

) ;; end library (mlir ir rewriter-base)

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir core builder) — MLIR builder API and dynamic builder context.
;;
;; Mirrors mlir/IR/Builders.h. Provides:
;;   - Dynamic context parameters (current-rewriter, current-block-builder,
;;     current-loc) and their RAII macros.
;;   - mlir-build-operation: context-dispatching op constructor.
;;   - Low-level builder FFI (block/region management).
;;   - Generic with-raii.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir core builder)
  (export
    ;; Dynamic builder context
    current-rewriter
    current-block-builder
    current-loc
    ;; Context-dispatching constructor
    mlir-build-operation
    ;; RAII macros
    with-raii
    with-op-builder
    with-operation-state
    with-rewrite-builder
    with-current-block-builder
    with-block-builder
    with-op-location
    ;; Canonical low-level rewriter ops
    mlir-ir-rewriter-base-create
    mlir-ir-rewriter-base-create-with-regions
    mlir-ir-op-builder-create
    mlir-ir-op-builder-create-with-regions
    mlir-ir-rewriter-base-set-insertion-point         ;; canonical: mlir::RewriterBase::setInsertionPoint(op)
    mlir-ir-rewriter-base-set-insertion-point-before  ;; backward-compat alias
    mlir-ir-rewriter-base-set-insertion-point-to-end
    mlir-ir-rewriter-base-create-block
    mlir-ir-rewriter-base-replace-op
    mlir-ir-rewriter-base-erase-op
    mlir-ir-rewriter-base-clone-with-types
    mlir-ir-op-builder-at-block-end
    mlir-ir-op-builder-destroy
    ;; OperationState primitives
    mlir-ir-operation-state-create
    mlir-ir-operation-state-add-operands        ;; canonical: mlir::OperationState::addOperands
    mlir-ir-operation-state-add-operand         ;; backward-compat alias
    mlir-ir-operation-state-add-types           ;; canonical: mlir::OperationState::addTypes
    mlir-ir-operation-state-add-result-type     ;; backward-compat alias
    mlir-ir-operation-state-add-region
    mlir-ir-operation-state-destroy
    mlir-ir-rewriter-base-create-from-state
    mlir-ir-op-builder-create-from-state
    ;; Block / region primitives (canonical names)
    mlir-ir-operation-get-region
    mlir::Block::getArgument
    mlir::Region::push_back<Block>
    ;; Pattern application (canonical name)
    mlir-transforms-greedy-pattern-rewrite-driver-apply
    ;; Legacy public aliases (backward compatibility)
    mlir-build-op
    mlir-replace-op
    mlir-erase-op
    mlir-op-erase
    mlir-set-insertion-point-before
    mlir-set-insertion-point-to-block-end
    mlir-op-get-region
    mlir-region-create-block
    mlir-block-get-argument
    mlir-new-block
    mlir-builder-at-block-end
    mlir-destroy-builder
    mlir-create-op
    mlir-apply-patterns-greedy
    mlir-op-clone-with-types
)

  (import (rnrs)
          (only (chezscheme) foreign-procedure parameterize make-parameter void)
          (mlir ir mlir-context)
          (only (mlir ir operation) mlir::Operation::getContext mlir::Operation::getLoc))

  (define mlir-Operation::getContext mlir::Operation::getContext)
  (define mlir-Operation::getLoc     mlir::Operation::getLoc)

  ;;===--------------------------------------------------------------------===;;
  ;; Canonical low-level rewriter FFI
  ;;===--------------------------------------------------------------------===;;

  ;; @brief mlir::RewriterBase::create — set insertion point before loc-op and
  ;;        create a new op with the given name, operands, and result types.
  ;; @param rewriter     RewriterBase* uptr
  ;; @param loc-op       Operation* uptr — insertion-point anchor and location source
  ;; @param name         string — fully-qualified op name, e.g. "arith.addi"
  ;; @param operands     Scheme list of Value* uptrs
  ;; @param result-types Scheme list of Type* uptrs
  ;; @return             Operation* uptr of the created op
  ;; @see   mlir/IR/Builders.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-rewriter-base-create
    (foreign-procedure "mlir_ir_rewriter_base_create"
                       (uptr uptr string scheme-object scheme-object) uptr))

  ;; @brief mlir::RewriterBase::create (with regions) — same as
  ;;        mlir-ir-rewriter-base-create but pre-allocates num-regions empty regions.
  ;; @param rewriter     RewriterBase* uptr
  ;; @param loc-op       Operation* uptr — insertion-point anchor and location source
  ;; @param name         string — fully-qualified op name
  ;; @param operands     Scheme list of Value* uptrs
  ;; @param result-types Scheme list of Type* uptrs
  ;; @param num-regions  int — number of empty regions to pre-allocate
  ;; @return             Operation* uptr of the created op
  ;; @see   mlir/IR/Builders.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-rewriter-base-create-with-regions
    (foreign-procedure "mlir_ir_rewriter_base_create_with_regions"
                       (uptr uptr string scheme-object scheme-object int) uptr))

  ;; @brief mlir::OpBuilder::create — create a new op via a plain OpBuilder
  ;;        (not a RewriterBase); does not move the rewriter insertion point.
  ;; @param builder      OpBuilder* uptr
  ;; @param loc-op       Operation* uptr — used as location source
  ;; @param name         string — fully-qualified op name
  ;; @param operands     Scheme list of Value* uptrs
  ;; @param result-types Scheme list of Type* uptrs
  ;; @return             Operation* uptr of the created op
  ;; @see   mlir/IR/Builders.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-op-builder-create
    (foreign-procedure "mlir_ir_op_builder_create"
                       (uptr uptr string scheme-object scheme-object) uptr))

  ;; @brief mlir::OpBuilder::create (with regions) — same as
  ;;        mlir-ir-op-builder-create but pre-allocates num-regions empty regions.
  ;; @param builder      OpBuilder* uptr
  ;; @param loc-op       Operation* uptr — used as location source
  ;; @param name         string — fully-qualified op name
  ;; @param operands     Scheme list of Value* uptrs
  ;; @param result-types Scheme list of Type* uptrs
  ;; @param num-regions  int — number of empty regions to pre-allocate
  ;; @return             Operation* uptr of the created op
  ;; @see   mlir/IR/Builders.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-op-builder-create-with-regions
    (foreign-procedure "mlir_ir_op_builder_create_with_regions"
                       (uptr uptr string scheme-object scheme-object int) uptr))

  ;; @brief mlir::RewriterBase::setInsertionPoint(op) — move the insertion point
  ;;        to immediately before the given op.
  ;; @param rewriter RewriterBase* uptr
  ;; @param op       Operation* uptr — new insertion-point anchor
  ;; @return         void
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-rewriter-base-set-insertion-point
    (foreign-procedure "mlir_ir_rewriter_base_set_insertion_point"
                       (uptr uptr) void))
  ;; @brief Backward-compat alias for mlir-ir-rewriter-base-set-insertion-point.
  ;; @see   mlir-ir-rewriter-base-set-insertion-point
  (define mlir-ir-rewriter-base-set-insertion-point-before
    mlir-ir-rewriter-base-set-insertion-point)

  ;; @brief mlir::RewriterBase::setInsertionPointToEnd(block) — move the
  ;;        insertion point to the end of the given block.
  ;; @param rewriter RewriterBase* uptr
  ;; @param block    Block* uptr
  ;; @return         void
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-rewriter-base-set-insertion-point-to-end
    (foreign-procedure "mlir_ir_rewriter_base_set_insertion_point_to_end"
                       (uptr uptr) void))

  ;; @brief mlir::RewriterBase::createBlock(region) — append a new block with
  ;;        the given argument types to a region and set IP to its end.
  ;; @param rewriter  RewriterBase* uptr
  ;; @param region    Region* uptr — region to append the new block to
  ;; @param arg-types Scheme list of Type* uptrs — block argument types
  ;; @return          Block* uptr of the newly created block
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-rewriter-base-create-block
    (foreign-procedure "mlir_ir_rewriter_base_create_block"
                       (uptr uptr scheme-object) uptr))

  ;; @brief mlir::RewriterBase::replaceOp — replace old-op's results with new-val.
  ;; @param rewriter RewriterBase* uptr
  ;; @param old-op   Operation* uptr — op to replace (must have no remaining uses)
  ;; @param new-val  Value* opaque uptr — replacement value
  ;; @return         1 on success, 0 on failure
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-rewriter-base-replace-op
    (foreign-procedure "mlir_ir_rewriter_base_replace_op" (uptr uptr uptr) int))

  ;; @brief mlir::RewriterBase::eraseOp — erase an op via the rewriter.
  ;; @param rewriter RewriterBase* uptr
  ;; @param op       Operation* uptr — op to erase (must have no uses)
  ;; @return         1 on success, 0 on failure
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-rewriter-base-erase-op
    (foreign-procedure "mlir_ir_rewriter_base_erase_op" (uptr uptr) int))

  ;; @brief Clone an op with new operands and result types via RewriterBase,
  ;;        copying all attributes from the original op.
  ;; @param rewriter     RewriterBase* uptr
  ;; @param op           Operation* uptr — op to clone
  ;; @param new-operands Scheme list of Value* uptrs — replacement operands
  ;; @param new-types    Scheme list of Type* uptrs — replacement result types
  ;; @return             Operation* uptr of the cloned op
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-rewriter-base-clone-with-types
    (foreign-procedure "mlir_ir_rewriter_base_clone_with_types"
                       (uptr uptr scheme-object scheme-object) uptr))

  ;; @brief Heap-allocate an OpBuilder positioned at the end of a block.
  ;; @param block   Block* uptr — block to position the builder at
  ;; @return        OpBuilder* uptr — must be freed with mlir-ir-op-builder-destroy
  ;; @see   mlir/IR/Builders.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-op-builder-at-block-end
    (foreign-procedure "mlir_ir_op_builder_at_block_end" (uptr) uptr))

  ;; @brief Free an OpBuilder created by mlir-ir-op-builder-at-block-end.
  ;; @param builder OpBuilder* uptr — must not be used after this call
  ;; @return        void
  ;; @see   mlir/IR/Builders.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-op-builder-destroy
    (foreign-procedure "mlir_ir_op_builder_destroy" (uptr) void))

  ;;===--------------------------------------------------------------------===;;
  ;; OperationState FFI (per-element, Scheme-side iteration)
  ;;===--------------------------------------------------------------------===;;

  ;; @brief mlir::OperationState constructor — create a heap-allocated
  ;;        OperationState for the named op at the given location.
  ;; @param loc  Location opaque uptr (from mlir-Operation::getLoc)
  ;; @param name string — fully-qualified op name, e.g. "arith.constant"
  ;; @return     OperationState* uptr — must be freed with
  ;;             mlir-ir-operation-state-destroy
  ;; @see   mlir/IR/Operation.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-operation-state-create
    (foreign-procedure "mlir_ir_operation_state_create" (uptr string) uptr))

  ;; @brief mlir::OperationState::addOperands — append one operand Value to an
  ;;        OperationState.
  ;; @param state OperationState* uptr
  ;; @param value Value* opaque uptr — operand to append
  ;; @return      void
  ;; @see   mlir/IR/Operation.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-operation-state-add-operands
    (foreign-procedure "mlir_ir_operation_state_add_operands" (uptr uptr) void))
  ;; @brief Backward-compat alias for mlir-ir-operation-state-add-operands.
  ;; @see   mlir-ir-operation-state-add-operands
  (define mlir-ir-operation-state-add-operand mlir-ir-operation-state-add-operands)

  ;; @brief mlir::OperationState::addTypes — append one result Type to an
  ;;        OperationState.
  ;; @param state OperationState* uptr
  ;; @param type  Type* opaque uptr — result type to append
  ;; @return      void
  ;; @see   mlir/IR/Operation.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-operation-state-add-types
    (foreign-procedure "mlir_ir_operation_state_add_types" (uptr uptr) void))
  ;; @brief Backward-compat alias for mlir-ir-operation-state-add-types.
  ;; @see   mlir-ir-operation-state-add-types
  (define mlir-ir-operation-state-add-result-type mlir-ir-operation-state-add-types)

  ;; @brief mlir::OperationState::addRegion — append one empty region to an
  ;;        OperationState.
  ;; @param state OperationState* uptr
  ;; @return      void
  ;; @see   mlir/IR/Operation.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-operation-state-add-region
    (foreign-procedure "mlir_ir_operation_state_add_region" (uptr) void))

  ;; @brief mlir::OperationState destructor — free an OperationState.
  ;; @param state OperationState* uptr — must not be used after this call
  ;; @return      void
  ;; @see   mlir/IR/Operation.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-operation-state-destroy
    (foreign-procedure "mlir_ir_operation_state_destroy" (uptr) void))

  ;; @brief mlir::RewriterBase::create(OperationState) — create an op from a
  ;;        fully-prepared OperationState.
  ;; @param rewriter RewriterBase* uptr
  ;; @param state    OperationState* uptr — prepared with operands/types/regions
  ;; @return         Operation* uptr of the created op
  ;; @see   mlir/IR/PatternMatch.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-rewriter-base-create-from-state
    (foreign-procedure "mlir_ir_rewriter_base_create_from_state" (uptr uptr) uptr))

  ;; @brief mlir::OpBuilder::create(OperationState) — create an op from a
  ;;        fully-prepared OperationState using a plain OpBuilder.
  ;; @param builder OpBuilder* uptr
  ;; @param state   OperationState* uptr — prepared with operands/types/regions
  ;; @return        Operation* uptr of the created op
  ;; @see   mlir/IR/Builders.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-op-builder-create-from-state
    (foreign-procedure "mlir_ir_op_builder_create_from_state" (uptr uptr) uptr))

  ;;===--------------------------------------------------------------------===;;
  ;; Block / region FFI (canonical names)
  ;;===--------------------------------------------------------------------===;;

  ;; @brief mlir::Operation::getRegion — get the i-th region of an operation.
  ;; @param op Operation* uptr
  ;; @param i  int — zero-based region index
  ;; @return   Region* uptr
  ;; @see   mlir/IR/Operation.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir-ir-operation-get-region
    (foreign-procedure "mlir::Operation::getRegion" (uptr int) uptr))

  ;; @brief mlir::Block::getArgument — get the idx-th argument of a block.
  ;; @param block Block* uptr
  ;; @param idx   int — zero-based argument index
  ;; @return      Value* opaque uptr of the block argument
  ;; @see   mlir/IR/Block.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir::Block::getArgument
    (foreign-procedure "mlir::Block::getArgument" (uptr int) uptr))

  ;; @brief mlir::Region::push_back<Block> — append a new Block with the given
  ;;        argument types to the end of a region.
  ;; @param region    Region* uptr
  ;; @param arg-types Scheme list of Type* uptrs — types for the block arguments
  ;; @return          Block* uptr of the newly appended block
  ;; @see   mlir/IR/Region.h
  ;; @note  Defined in lib/Bindings/IR/Builder.cpp
  (define mlir::Region::push_back<Block>
    (foreign-procedure "mlir::Region::push_back<Block>" (uptr scheme-object) uptr))

  ;; @brief mlir::Operation::erase — erase an op directly without a rewriter
  ;;        (for post-pass cleanup).
  ;; @param op Operation* uptr — must have no uses before calling erase
  ;; @return   void
  ;; @see   mlir/IR/Operation.h
  ;; @note  Defined in MLIR core; no dedicated CREST binding wrapper
  (define mlir-op-erase
    (foreign-procedure "mlir::Operation::erase" (uptr) void))

  ;;===--------------------------------------------------------------------===;;
  ;; Pattern application (canonical name)
  ;;===--------------------------------------------------------------------===;;

  ;; @brief mlir::applyPatternsGreedily — greedy worklist-driven pattern application
  ;;        (canonical name in the builder module).
  ;; @param op       Operation* uptr — root op to rewrite
  ;; @param patterns RewritePatternSet* uptr (consumed/moved)
  ;; @return         boolean — #t on success (fixed point), #f on failure
  ;; @see   mlir/Transforms/GreedyPatternRewriteDriver.h
  ;; @note  Defined in lib/Bindings/Transforms/GreedyPatternRewriteDriver.cpp
  (define mlir-transforms-greedy-pattern-rewrite-driver-apply
    (foreign-procedure "mlir_transforms_greedy_pattern_rewrite_driver_apply"
                       (uptr uptr) boolean))

  ;;===--------------------------------------------------------------------===;;
  ;; Generic RAII
  ;;===--------------------------------------------------------------------===;;

  ;; @brief macro: with-raii — single-resource RAII.  Bind VAR to (CTOR), run
  ;;        BODY, call (DTOR VAR) on exit whether BODY returns, raises, or escapes.
  ;; @param var  identifier bound to the resource for BODY
  ;; @param ctor expression that creates the resource (evaluated once)
  ;; @param dtor procedure called on VAR when BODY exits (via dynamic-wind)
  ;; @param body forms to evaluate with var in scope
  (define-syntax with-raii
    (syntax-rules ()
      [(_ (var ctor dtor) body ...)
       (let ([var ctor])
         (dynamic-wind void
           (lambda () body ...)
           (lambda () (dtor var))))]))

  ;; @brief macro: with-op-builder — RAII for a heap-allocated OpBuilder.
  ;;        Calls mlir-ir-op-builder-at-block-end on BLOCK, binds the result to
  ;;        BUILDER, runs BODY, then calls mlir-ir-op-builder-destroy on exit.
  ;; @param builder identifier bound to the OpBuilder* uptr for BODY
  ;; @param block   Block* uptr — block to position the builder at
  ;; @param body    forms to evaluate with builder in scope
  (define-syntax with-op-builder
    (syntax-rules ()
      [(_ (builder block) body ...)
       (let ([builder (mlir-ir-op-builder-at-block-end block)])
         (dynamic-wind
           (lambda () #f)
           (lambda () body ...)
           (lambda () (mlir-ir-op-builder-destroy builder))))]))

  ;; @brief macro: with-operation-state — RAII for a heap-allocated OperationState.
  ;;        Creates STATE via mlir-ir-operation-state-create(LOC, NAME), runs BODY,
  ;;        then destroys the state on exit via mlir-ir-operation-state-destroy.
  ;; @param state identifier bound to the OperationState* uptr for BODY
  ;; @param loc   Location opaque uptr (from mlir-Operation::getLoc)
  ;; @param name  string — fully-qualified op name, e.g. "arith.addi"
  ;; @param body  forms to evaluate with state in scope
  (define-syntax with-operation-state
    (syntax-rules ()
      [(_ (state loc name) body ...)
       (let ([state (mlir-ir-operation-state-create loc name)])
         (dynamic-wind
           (lambda () #f)
           (lambda () body ...)
           (lambda () (mlir-ir-operation-state-destroy state))))]))

  ;;===--------------------------------------------------------------------===;;
  ;; Dynamic builder context
  ;;===--------------------------------------------------------------------===;;

  ;; @brief Dynamic parameter — current ConversionPatternRewriter* uptr, or #f
  ;;        when not in a pattern callback.  Set by with-rewrite-builder.
  (define current-rewriter      (make-parameter #f))

  ;; @brief Dynamic parameter — current OpBuilder* uptr for region/block filling,
  ;;        or #f when a rewriter is active.  Set by with-current-block-builder /
  ;;        with-block-builder.
  (define current-block-builder (make-parameter #f))

  ;; @brief Dynamic parameter — current location source Operation* uptr, or #f
  ;;        when unset.  Used by mlir-build-operation as the loc anchor.
  ;;        Override temporarily with with-op-location.
  (define current-loc           (make-parameter #f))

  ;; @brief mlir-build-operation — context-dispatching op constructor.
  ;;        Dispatches to current-rewriter if installed, else to
  ;;        current-block-builder; raises if neither is active.
  ;; @param name     string — fully-qualified op name, e.g. "arith.constant"
  ;; @param operands Scheme list of Value* uptrs
  ;; @param types    Scheme list of result Type* uptrs
  ;; @param nregions int (optional) — empty regions to pre-allocate (default 0)
  ;; @return         Operation* uptr of the created op
  ;; @note  Iteration over operands/types is done in Scheme for thin C-call overhead.
  (define (mlir-build-operation name operands types . rest)
    (let ([nregions (if (pair? rest) (car rest) 0)]
          [loc-op   (current-loc)])
      (cond
        [(current-rewriter) =>
         (lambda (rw)
           (mlir-ir-rewriter-base-set-insertion-point rw loc-op)
           (with-operation-state (state (mlir-Operation::getLoc loc-op) name)
             (for-each (lambda (v) (mlir-ir-operation-state-add-operands state v))
                       operands)
             (for-each (lambda (t) (mlir-ir-operation-state-add-types state t))
                       types)
             (let loop ([i 0])
               (when (< i nregions)
                 (mlir-ir-operation-state-add-region state)
                 (loop (+ i 1))))
             (mlir-ir-rewriter-base-create-from-state rw state)))]
        [(current-block-builder) =>
         (lambda (b)
           (with-operation-state (state (mlir-Operation::getLoc loc-op) name)
             (for-each (lambda (v) (mlir-ir-operation-state-add-operands state v))
                       operands)
             (for-each (lambda (t) (mlir-ir-operation-state-add-types state t))
                       types)
             (let loop ([i 0])
               (when (< i nregions)
                 (mlir-ir-operation-state-add-region state)
                 (loop (+ i 1))))
             (mlir-ir-op-builder-create-from-state b state)))]
        [else (error 'mlir-build-operation "no current builder installed")])))

  ;; @brief macro: with-rewrite-builder — install a RewriterBase as the active
  ;;        builder context for BODY.  Sets current-rewriter, current-loc, and
  ;;        current-mlir-context; clears current-block-builder.
  ;; @param rw   RewriterBase* uptr — passed by the pattern callback
  ;; @param loc  Operation* uptr — insertion-point anchor and location source
  ;; @param body forms to evaluate with the rewriter active
  (define-syntax with-rewrite-builder
    (syntax-rules ()
      [(_ (rw loc) body ...)
       (parameterize ([current-rewriter      rw]
                      [current-block-builder #f]
                      [current-loc           loc]
                      [current-mlir-context  (mlir-Operation::getContext loc)])
         body ...)]))

  ;; @brief macro: with-current-block-builder — install an explicit OpBuilder*
  ;;        as the active block-builder context for BODY.  Sets
  ;;        current-block-builder, current-loc, and current-mlir-context;
  ;;        clears current-rewriter.
  ;; @param builder OpBuilder* uptr
  ;; @param loc     Operation* uptr — location source for ops created in BODY
  ;; @param body    forms to evaluate with the block builder active
  (define-syntax with-current-block-builder
    (syntax-rules ()
      [(_ (builder loc) body ...)
       (parameterize ([current-block-builder builder]
                      [current-rewriter      #f]
                      [current-loc           loc]
                      [current-mlir-context  (mlir-Operation::getContext loc)])
         body ...)]))

  ;; @brief macro: with-block-builder — create an OpBuilder at the end of BLOCK,
  ;;        install it as current-block-builder, run BODY, then destroy the builder.
  ;;        Inherits current-loc from the enclosing scope.
  ;; @param block Block* uptr — block to position the builder at
  ;; @param body  forms to evaluate with the new block builder installed
  (define-syntax with-block-builder
    (syntax-rules ()
      [(_ block body ...)
       (with-op-builder (%builder block)
         (parameterize ([current-block-builder %builder]
                        [current-rewriter #f])
           body ...))]))

  ;; @brief macro: with-op-location — temporarily override current-loc with LOC
  ;;        for the duration of BODY.
  ;; @param loc  Operation* uptr — new location/insertion-point source
  ;; @param body forms to evaluate with the overridden location
  (define-syntax with-op-location
    (syntax-rules ()
      [(_ loc body ...)
       (parameterize ([current-loc loc]) body ...)]))

  ;;===--------------------------------------------------------------------===;;
  ;; Legacy public aliases (backward compatibility)
  ;;===--------------------------------------------------------------------===;;

  ;; @brief Legacy alias for mlir-ir-rewriter-base-create.
  ;; @see   mlir-ir-rewriter-base-create
  (define mlir-build-op mlir-ir-rewriter-base-create)

  ;; @brief Legacy alias for mlir-ir-rewriter-base-replace-op.
  ;; @see   mlir-ir-rewriter-base-replace-op
  (define mlir-replace-op mlir-ir-rewriter-base-replace-op)

  ;; @brief Legacy alias for mlir-ir-rewriter-base-erase-op.
  ;; @see   mlir-ir-rewriter-base-erase-op
  (define mlir-erase-op mlir-ir-rewriter-base-erase-op)

  ;; @brief Legacy alias for mlir-ir-rewriter-base-set-insertion-point.
  ;; @see   mlir-ir-rewriter-base-set-insertion-point
  (define mlir-set-insertion-point-before
    mlir-ir-rewriter-base-set-insertion-point)

  ;; @brief Legacy alias for mlir-ir-rewriter-base-set-insertion-point-to-end.
  ;; @see   mlir-ir-rewriter-base-set-insertion-point-to-end
  (define mlir-set-insertion-point-to-block-end
    mlir-ir-rewriter-base-set-insertion-point-to-end)

  ;; @brief Legacy alias for mlir-ir-operation-get-region.
  ;; @see   mlir-ir-operation-get-region
  (define mlir-op-get-region mlir-ir-operation-get-region)

  ;; @brief Legacy alias for mlir-ir-rewriter-base-create-block.
  ;; @see   mlir-ir-rewriter-base-create-block
  (define mlir-region-create-block mlir-ir-rewriter-base-create-block)

  ;; @brief Legacy alias for mlir::Block::getArgument.
  ;; @see   mlir::Block::getArgument
  (define mlir-block-get-argument mlir::Block::getArgument)

  ;; @brief Legacy alias for mlir::Region::push_back<Block>.
  ;; @see   mlir::Region::push_back<Block>
  (define mlir-new-block mlir::Region::push_back<Block>)

  ;; @brief Legacy alias for mlir-ir-op-builder-at-block-end.
  ;; @see   mlir-ir-op-builder-at-block-end
  (define mlir-builder-at-block-end mlir-ir-op-builder-at-block-end)

  ;; @brief Legacy alias for mlir-ir-op-builder-destroy.
  ;; @see   mlir-ir-op-builder-destroy
  (define mlir-destroy-builder mlir-ir-op-builder-destroy)

  ;; @brief mlir-create-op — low-level op creation via an explicit OpBuilder*
  ;;        (not a rewriter); functional version of mlir-ir-op-builder-create
  ;;        that handles OperationState lifecycle.
  ;; @param builder    OpBuilder* uptr
  ;; @param loc        Operation* uptr — location source
  ;; @param name       string — fully-qualified op name
  ;; @param ops        Scheme list of Value* uptrs — operands
  ;; @param types      Scheme list of Type* uptrs — result types
  ;; @param num-regions int (optional) — empty regions to pre-allocate (default 0)
  ;; @return           Operation* uptr of the created op
  (define (mlir-create-op builder loc name ops types . rest)
    (let ([nregions (if (pair? rest) (car rest) 0)])
      (with-operation-state (state (mlir-Operation::getLoc loc) name)
        (for-each (lambda (v) (mlir-ir-operation-state-add-operands state v)) ops)
        (for-each (lambda (t) (mlir-ir-operation-state-add-types state t)) types)
        (let loop ([i 0])
          (when (< i nregions)
            (mlir-ir-operation-state-add-region state)
            (loop (+ i 1))))
        (mlir-ir-op-builder-create-from-state builder state))))

  ;; @brief Legacy alias for mlir-transforms-greedy-pattern-rewrite-driver-apply.
  ;; @see   mlir-transforms-greedy-pattern-rewrite-driver-apply
  (define mlir-apply-patterns-greedy
    mlir-transforms-greedy-pattern-rewrite-driver-apply)

  ;; @brief Legacy alias for mlir-ir-rewriter-base-clone-with-types.
  ;; @see   mlir-ir-rewriter-base-clone-with-types
  (define mlir-op-clone-with-types mlir-ir-rewriter-base-clone-with-types)

) ;; end library (mlir core builder)

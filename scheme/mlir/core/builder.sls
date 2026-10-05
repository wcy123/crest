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

  ;; mlir::RewriterBase::create — set insertion point before loc_op and create.
  ;; rewriter: RewriterBase* uptr, loc-op: Operation* uptr
  ;; name: string, operands: Scheme list of Value* uptrs
  ;; result-types: Scheme list of Type* uptrs
  ;; Returns: Operation* uptr
  (define mlir-ir-rewriter-base-create
    (foreign-procedure "mlir_ir_rewriter_base_create"
                       (uptr uptr string scheme-object scheme-object) uptr))

  ;; Like mlir-ir-rewriter-base-create but pre-allocates num-regions empty regions.
  (define mlir-ir-rewriter-base-create-with-regions
    (foreign-procedure "mlir_ir_rewriter_base_create_with_regions"
                       (uptr uptr string scheme-object scheme-object int) uptr))

  ;; mlir::OpBuilder::create — create via a plain OpBuilder (not a RewriterBase).
  ;; builder: OpBuilder* uptr, loc-op: Operation* uptr
  ;; name: string, operands: Scheme list, result-types: Scheme list
  ;; Returns: Operation* uptr
  (define mlir-ir-op-builder-create
    (foreign-procedure "mlir_ir_op_builder_create"
                       (uptr uptr string scheme-object scheme-object) uptr))

  ;; Like mlir-ir-op-builder-create but pre-allocates num-regions empty regions.
  (define mlir-ir-op-builder-create-with-regions
    (foreign-procedure "mlir_ir_op_builder_create_with_regions"
                       (uptr uptr string scheme-object scheme-object int) uptr))

  ;; mlir::RewriterBase::setInsertionPoint(op)
  (define mlir-ir-rewriter-base-set-insertion-point
    (foreign-procedure "mlir_ir_rewriter_base_set_insertion_point"
                       (uptr uptr) void))
  ;; Backward-compat alias
  (define mlir-ir-rewriter-base-set-insertion-point-before
    mlir-ir-rewriter-base-set-insertion-point)

  ;; mlir::RewriterBase::setInsertionPointToEnd(block)
  (define mlir-ir-rewriter-base-set-insertion-point-to-end
    (foreign-procedure "mlir_ir_rewriter_base_set_insertion_point_to_end"
                       (uptr uptr) void))

  ;; mlir::RewriterBase::createBlock(region) + add typed block arguments.
  ;; rewriter: RewriterBase* uptr, region: Region* uptr
  ;; arg-types: Scheme list of Type* uptrs
  ;; Returns: Block* uptr
  (define mlir-ir-rewriter-base-create-block
    (foreign-procedure "mlir_ir_rewriter_base_create_block"
                       (uptr uptr scheme-object) uptr))

  ;; mlir::RewriterBase::replaceOp
  (define mlir-ir-rewriter-base-replace-op
    (foreign-procedure "mlir_ir_rewriter_base_replace_op" (uptr uptr uptr) int))

  ;; mlir::RewriterBase::eraseOp
  (define mlir-ir-rewriter-base-erase-op
    (foreign-procedure "mlir_ir_rewriter_base_erase_op" (uptr uptr) int))

  ;; Clone an op with new operands/types via RewriterBase, copying attributes.
  (define mlir-ir-rewriter-base-clone-with-types
    (foreign-procedure "mlir_ir_rewriter_base_clone_with_types"
                       (uptr uptr scheme-object scheme-object) uptr))

  ;; Heap-allocate an OpBuilder positioned at the end of a block.
  ;; block: Block* uptr
  ;; Returns: OpBuilder* uptr — must be destroyed with mlir-ir-op-builder-destroy
  (define mlir-ir-op-builder-at-block-end
    (foreign-procedure "mlir_ir_op_builder_at_block_end" (uptr) uptr))

  ;; Destroy an OpBuilder created by mlir-ir-op-builder-at-block-end.
  (define mlir-ir-op-builder-destroy
    (foreign-procedure "mlir_ir_op_builder_destroy" (uptr) void))

  ;;===--------------------------------------------------------------------===;;
  ;; OperationState FFI (per-element, Scheme-side iteration)
  ;;===--------------------------------------------------------------------===;;

  ;; Create a heap-allocated OperationState.
  ;; loc: Location opaque ptr uptr (from mlir-Operation::getLoc)
  ;; name: string op name
  ;; Returns: OperationState* uptr — must be destroyed with
  ;;          mlir-ir-operation-state-destroy
  (define mlir-ir-operation-state-create
    (foreign-procedure "mlir_ir_operation_state_create" (uptr string) uptr))

  ;; Add one operand Value to an OperationState — mlir::OperationState::addOperands.
  ;; state: OperationState* uptr, value: Value* opaque ptr uptr
  (define mlir-ir-operation-state-add-operands
    (foreign-procedure "mlir_ir_operation_state_add_operands" (uptr uptr) void))
  ;; Backward-compat alias
  (define mlir-ir-operation-state-add-operand mlir-ir-operation-state-add-operands)

  ;; Add one result Type to an OperationState — mlir::OperationState::addTypes.
  ;; state: OperationState* uptr, type: Type* opaque ptr uptr
  (define mlir-ir-operation-state-add-types
    (foreign-procedure "mlir_ir_operation_state_add_types" (uptr uptr) void))
  ;; Backward-compat alias
  (define mlir-ir-operation-state-add-result-type mlir-ir-operation-state-add-types)

  ;; Add one empty region to an OperationState.
  ;; state: OperationState* uptr
  (define mlir-ir-operation-state-add-region
    (foreign-procedure "mlir_ir_operation_state_add_region" (uptr) void))

  ;; Destroy an OperationState created by mlir-ir-operation-state-create.
  (define mlir-ir-operation-state-destroy
    (foreign-procedure "mlir_ir_operation_state_destroy" (uptr) void))

  ;; Create an op via RewriterBase from a prepared OperationState.
  ;; rw: RewriterBase* uptr, state: OperationState* uptr
  ;; Returns: Operation* uptr
  (define mlir-ir-rewriter-base-create-from-state
    (foreign-procedure "mlir_ir_rewriter_base_create_from_state" (uptr uptr) uptr))

  ;; Create an op via OpBuilder from a prepared OperationState.
  ;; builder: OpBuilder* uptr, state: OperationState* uptr
  ;; Returns: Operation* uptr
  (define mlir-ir-op-builder-create-from-state
    (foreign-procedure "mlir_ir_op_builder_create_from_state" (uptr uptr) uptr))

  ;;===--------------------------------------------------------------------===;;
  ;; Block / region FFI (canonical names)
  ;;===--------------------------------------------------------------------===;;

  ;; Get the i-th region of an operation.
  ;; op: Operation* uptr, i: 0-based region index
  ;; Returns: Region* uptr
  (define mlir-ir-operation-get-region
    (foreign-procedure "mlir::Operation::getRegion" (uptr int) uptr))

  ;; Get the idx-th argument of a Block directly by index.
  ;; block: Block* uptr, idx: 0-based argument index
  ;; Returns: Value* opaque ptr uptr
  (define mlir::Block::getArgument
    (foreign-procedure "mlir::Block::getArgument" (uptr int) uptr))

  ;; Append a new Block to a region with given argument types.
  ;; region: Region* uptr, arg-types: Scheme list of Type* uptrs
  ;; Returns: Block* uptr
  (define mlir::Region::push_back<Block>
    (foreign-procedure "mlir::Region::push_back<Block>" (uptr scheme-object) uptr))

  ;; Erase an op directly without a rewriter (for post-pass cleanup).
  ;; op: Operation* uptr — must have no uses
  (define mlir-op-erase
    (foreign-procedure "mlir::Operation::erase" (uptr) void))

  ;;===--------------------------------------------------------------------===;;
  ;; Pattern application (canonical name)
  ;;===--------------------------------------------------------------------===;;

  (define mlir-transforms-greedy-pattern-rewrite-driver-apply
    (foreign-procedure "mlir_transforms_greedy_pattern_rewrite_driver_apply"
                       (uptr uptr) boolean))

  ;;===--------------------------------------------------------------------===;;
  ;; Generic RAII
  ;;===--------------------------------------------------------------------===;;

  ;; Single-resource RAII: bind var to (ctor), run body, call (dtor var) on exit.
  ;; Cleanup fires whether body returns normally, raises, or escapes.
  (define-syntax with-raii
    (syntax-rules ()
      [(_ (var ctor dtor) body ...)
       (let ([var ctor])
         (dynamic-wind void
           (lambda () body ...)
           (lambda () (dtor var))))]))

  ;; RAII wrapper for a heap-allocated OpBuilder positioned at the end of a block.
  ;; Calls mlir-ir-op-builder-at-block-end on entry,
  ;; mlir-ir-op-builder-destroy on exit.
  ;; builder is bound to the OpBuilder* uptr for the duration of body.
  (define-syntax with-op-builder
    (syntax-rules ()
      [(_ (builder block) body ...)
       (let ([builder (mlir-ir-op-builder-at-block-end block)])
         (dynamic-wind
           (lambda () #f)
           (lambda () body ...)
           (lambda () (mlir-ir-op-builder-destroy builder))))]))

  ;; RAII wrapper for a heap-allocated OperationState.
  ;; Creates state via mlir-ir-operation-state-create, runs body, destroys on exit.
  ;; state is bound to the OperationState* uptr for the duration of body.
  ;; loc: Location opaque ptr uptr, name: string op name
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

  ;; Current ConversionPatternRewriter* (or #f when not in a pattern callback).
  (define current-rewriter      (make-parameter #f))

  ;; Current OpBuilder* for region/block filling (or #f when using a rewriter).
  (define current-block-builder (make-parameter #f))

  ;; Current location source Operation* uptr (or #f when unset).
  ;; Used by mlir-build-operation as the loc argument to the build functions.
  (define current-loc           (make-parameter #f))

  ;; Build an op using whichever builder context is currently active.
  ;; Dispatches to the rewriter path if current-rewriter is set, otherwise
  ;; to the block-builder path.  Raises if neither is installed.
  ;; name:      string op name, e.g. "arith.constant"
  ;; operands:  Scheme list of Value* uptrs
  ;; types:     Scheme list of result Type* uptrs
  ;; nregions:  optional int — number of empty regions to pre-allocate (default 0)
  ;; Returns: Operation* uptr of the created op
  ;;
  ;; Uses with-operation-state so that list iteration happens in Scheme and
  ;; each C call is a thin per-element wrapper.
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

  ;; Install rw as current-rewriter and loc as current-loc for the duration of body.
  ;; Also installs current-mlir-context from the loc operation.
  ;; rw:  RewriterBase* uptr (passed by the pattern callback)
  ;; loc: Operation* uptr used as both the insertion-point anchor and location source
  (define-syntax with-rewrite-builder
    (syntax-rules ()
      [(_ (rw loc) body ...)
       (parameterize ([current-rewriter      rw]
                      [current-block-builder #f]
                      [current-loc           loc]
                      [current-mlir-context  (mlir-Operation::getContext loc)])
         body ...)]))

  ;; Install an explicit OpBuilder* as current-block-builder for the duration of body.
  ;; Also installs current-mlir-context from the loc operation.
  ;; builder: OpBuilder* uptr, loc: Operation* uptr (location source)
  (define-syntax with-current-block-builder
    (syntax-rules ()
      [(_ (builder loc) body ...)
       (parameterize ([current-block-builder builder]
                      [current-rewriter      #f]
                      [current-loc           loc]
                      [current-mlir-context  (mlir-Operation::getContext loc)])
         body ...)]))

  ;; Create an OpBuilder at the end of block, install it as current-block-builder,
  ;; run body, then destroy the builder.  Inherits current-loc from the enclosing scope.
  ;; block: Block* uptr
  (define-syntax with-block-builder
    (syntax-rules ()
      [(_ block body ...)
       (with-op-builder (%builder block)
         (parameterize ([current-block-builder %builder]
                        [current-rewriter #f])
           body ...))]))

  ;; Temporarily override current-loc with loc for the duration of body.
  ;; loc: Operation* uptr used as the location/insertion-point source
  (define-syntax with-op-location
    (syntax-rules ()
      [(_ loc body ...)
       (parameterize ([current-loc loc]) body ...)]))

  ;;===--------------------------------------------------------------------===;;
  ;; Legacy public aliases (backward compatibility)
  ;;===--------------------------------------------------------------------===;;

  ;; Build an op via RewriterBase (sets insertion point to before loc-op).
  ;; Kept for backward compatibility; prefer mlir-ir-rewriter-base-create.
  (define mlir-build-op mlir-ir-rewriter-base-create)

  ;; Replace old-op's results with new-val via the rewriter.
  (define mlir-replace-op mlir-ir-rewriter-base-replace-op)

  ;; Erase old-op via the rewriter.
  (define mlir-erase-op mlir-ir-rewriter-base-erase-op)

  ;; Set the rewriter's insertion point to immediately before op.
  (define mlir-set-insertion-point-before
    mlir-ir-rewriter-base-set-insertion-point)

  ;; Set the rewriter's insertion point to the end of a block.
  (define mlir-set-insertion-point-to-block-end
    mlir-ir-rewriter-base-set-insertion-point-to-end)

  ;; Get the i-th region of an operation.
  (define mlir-op-get-region mlir-ir-operation-get-region)

  ;; Create a block inside a region with given argument types; sets IP to its end.
  (define mlir-region-create-block mlir-ir-rewriter-base-create-block)

  ;; Get the i-th block argument as a Value* uptr.
  ;; block: Block* uptr, i: 0-based argument index
  (define mlir-block-get-argument mlir::Block::getArgument)

  ;; Create a new Block in a region with the given argument types.
  (define mlir-new-block mlir::Region::push_back<Block>)

  ;; Create a heap-allocated OpBuilder positioned at the end of a block.
  (define mlir-builder-at-block-end mlir-ir-op-builder-at-block-end)

  ;; Destroy an OpBuilder created by mlir-builder-at-block-end.
  (define mlir-destroy-builder mlir-ir-op-builder-destroy)

  ;; Low-level op creation via an explicit OpBuilder* (not a rewriter).
  ;; builder: OpBuilder* uptr, loc: Operation* uptr (source of location)
  ;; name: string, ops: Scheme list of Value* uptrs
  ;; types: Scheme list of Type* uptrs, num-regions: int (default 0)
  ;; Returns: Operation* uptr
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

  ;; Apply patterns greedily (legacy alias for canonical name).
  (define mlir-apply-patterns-greedy
    mlir-transforms-greedy-pattern-rewrite-driver-apply)

  ;; Clone an operation with new operands and result types, copying all attributes.
  (define mlir-op-clone-with-types mlir-ir-rewriter-base-clone-with-types)

) ;; end library (mlir core builder)

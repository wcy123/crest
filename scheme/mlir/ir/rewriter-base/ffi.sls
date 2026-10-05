#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir rewriter-base ffi) — raw C bindings for mlir/IR/PatternMatch.h RewriterBase.
;;
;; % prefix = raw C binding. Prefer (mlir ir rewriter-base) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir rewriter-base ffi)
  (export
    %rewriter-base-create
    %rewriter-base-create-with-regions
    %rewriter-base-set-insertion-point-before
    %rewriter-base-set-insertion-point-to-end
    %rewriter-base-create-block
    %rewriter-base-replace-op
    %rewriter-base-erase-op
    %rewriter-base-clone-with-types)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::RewriterBase::create — create an op via OperationState, setting insertion point before loc-op.
  ;; @param rewriter      RewriterBase* uptr (ConversionPatternRewriter or IRRewriter)
  ;; @param loc-op        Operation* uptr — insertion point and location source
  ;; @param op-name       Registered MLIR op name string (e.g. "arith.addi")
  ;; @param operands      Scheme list of Value* uptrs
  ;; @param result-types  Scheme list of Type* uptrs
  ;; @return              Operation* uptr of the created op, or 0 on bad input
  ;; @see                 mlir/IR/PatternMatch.h
  ;; @note                Defined in lib/Bindings/IR/RewriterBase.cpp
  (define %rewriter-base-create
    (foreign-procedure "mlir_ir_rewriter_base_create"
                       (uptr uptr string scheme-object scheme-object) uptr))

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
  (define %rewriter-base-create-with-regions
    (foreign-procedure "mlir_ir_rewriter_base_create_with_regions"
                       (uptr uptr string scheme-object scheme-object int) uptr))

  ;; @brief mlir::RewriterBase::setInsertionPoint(op) — move the rewriter's insertion point to before op.
  ;; @param rewriter  RewriterBase* uptr
  ;; @param op        Operation* uptr — target operation
  ;; @return          void
  ;; @see             mlir/IR/PatternMatch.h
  ;; @note            Defined in lib/Bindings/IR/RewriterBase.cpp
  (define %rewriter-base-set-insertion-point-before
    (foreign-procedure "mlir_ir_rewriter_base_set_insertion_point_before"
                       (uptr uptr) void))

  ;; @brief mlir::RewriterBase::setInsertionPointToEnd(block) — move the rewriter's insertion point to the end of block.
  ;; @param rewriter  RewriterBase* uptr
  ;; @param block     Block* uptr — target block
  ;; @return          void
  ;; @see             mlir/IR/PatternMatch.h
  ;; @note            Defined in lib/Bindings/IR/RewriterBase.cpp
  (define %rewriter-base-set-insertion-point-to-end
    (foreign-procedure "mlir_ir_rewriter_base_set_insertion_point_to_end"
                       (uptr uptr) void))

  ;; @brief mlir::RewriterBase::createBlock(region) — create a new block in region, add typed arguments, set insertion point to end.
  ;; @param rewriter       RewriterBase* uptr
  ;; @param region         Region* uptr — target region
  ;; @param arg-types      Scheme list of Type* uptrs for block arguments (may be '())
  ;; @return               Block* uptr of the newly created block, or 0 on bad input
  ;; @see                  mlir/IR/PatternMatch.h
  ;; @note                 Defined in lib/Bindings/IR/RewriterBase.cpp; sets insertion point to end of new block
  (define %rewriter-base-create-block
    (foreign-procedure "mlir_ir_rewriter_base_create_block"
                       (uptr uptr scheme-object) uptr))

  ;; @brief mlir::RewriterBase::replaceOp — replace old-op with a single new Value.
  ;; @param rewriter   RewriterBase* uptr
  ;; @param old-op     Operation* uptr — op to replace and erase
  ;; @param new-value  Value* uptr — replacement value
  ;; @return           1 on success, 0 if rewriter is null
  ;; @see              mlir/IR/PatternMatch.h
  ;; @note             Defined in lib/Bindings/IR/RewriterBase.cpp
  (define %rewriter-base-replace-op
    (foreign-procedure "mlir_ir_rewriter_base_replace_op"
                       (uptr uptr uptr) int))

  ;; @brief mlir::RewriterBase::eraseOp — erase op from its parent block (op must have no uses).
  ;; @param rewriter  RewriterBase* uptr
  ;; @param op        Operation* uptr — op to erase
  ;; @return          1 on success, 0 if rewriter is null
  ;; @see             mlir/IR/PatternMatch.h
  ;; @note            Defined in lib/Bindings/IR/RewriterBase.cpp
  (define %rewriter-base-erase-op
    (foreign-procedure "mlir_ir_rewriter_base_erase_op"
                       (uptr uptr) int))

  ;; @brief Clone op with new operands and result types, copying all attributes, then create via the rewriter.
  ;; @param rewriter      RewriterBase* uptr
  ;; @param op            Operation* uptr — template op (name and attributes are copied)
  ;; @param operands      Scheme list of Value* uptrs — new operand values
  ;; @param result-types  Scheme list of Type* uptrs — new result types
  ;; @return              Operation* uptr of the cloned op, or 0 on bad input
  ;; @see                 mlir/IR/PatternMatch.h
  ;; @note                Defined in lib/Bindings/IR/RewriterBase.cpp; uses op location for the new OperationState
  (define %rewriter-base-clone-with-types
    (foreign-procedure "mlir_ir_rewriter_base_clone_with_types"
                       (uptr uptr scheme-object scheme-object) uptr))

) ;; end library (mlir ir rewriter-base ffi)

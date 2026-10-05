#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir op-builder ffi) — raw C bindings for mlir/IR/Builders.h OpBuilder.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir op-builder ffi)
  (export
    %op-builder-create
    %op-builder-create-with-regions
    %op-builder-at-block-end
    %op-builder-destroy
    %op-builder-create-from-state)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::OpBuilder::create — create an op via OperationState using a standalone OpBuilder.
  ;; @param builder       OpBuilder* uptr — builder positioned at the desired insertion point
  ;; @param loc-op        Operation* uptr — location source for the new op
  ;; @param op-name       Registered MLIR op name string (e.g. "arith.addi")
  ;; @param operands      Scheme list of Value* uptrs
  ;; @param result-types  Scheme list of Type* uptrs
  ;; @return              Operation* uptr of the created op, or 0 on bad input
  ;; @see                 mlir/IR/Builders.h
  ;; @note                Defined in lib/Bindings/IR/OpBuilder.cpp
  (define %op-builder-create
    (foreign-procedure "mlir_ir_op_builder_create"
                       (uptr uptr string scheme-object scheme-object) uptr))

  ;; @brief mlir::OpBuilder::create — create an op with pre-allocated empty regions using a standalone OpBuilder.
  ;; @param builder       OpBuilder* uptr — builder positioned at the desired insertion point
  ;; @param loc-op        Operation* uptr — location source for the new op
  ;; @param op-name       Registered MLIR op name string
  ;; @param operands      Scheme list of Value* uptrs
  ;; @param result-types  Scheme list of Type* uptrs
  ;; @param num-regions   Number of empty regions to pre-allocate (int)
  ;; @return              Operation* uptr of the created op, or 0 on bad input
  ;; @see                 mlir/IR/Builders.h
  ;; @note                Defined in lib/Bindings/IR/OpBuilder.cpp
  (define %op-builder-create-with-regions
    (foreign-procedure "mlir_ir_op_builder_create_with_regions"
                       (uptr uptr string scheme-object scheme-object int) uptr))

  ;; @brief Heap-allocate an mlir::OpBuilder positioned at the end of block.
  ;; @param block   Block* uptr — target block; builder is positioned at block->end()
  ;; @return        OpBuilder* uptr (heap-allocated), or 0 if block is null
  ;; @see           mlir/IR/Builders.h
  ;; @note          Defined in lib/Bindings/IR/OpBuilder.cpp; caller must free via %op-builder-destroy
  (define %op-builder-at-block-end
    (foreign-procedure "mlir_ir_op_builder_at_block_end" (uptr) uptr))

  ;; @brief Destroy an mlir::OpBuilder created by %op-builder-at-block-end.
  ;; @param builder  OpBuilder* uptr — heap-allocated builder to delete
  ;; @return         void
  ;; @see            mlir/IR/Builders.h
  ;; @note           Defined in lib/Bindings/IR/OpBuilder.cpp; no-op if builder is 0
  (define %op-builder-destroy
    (foreign-procedure "mlir_ir_op_builder_destroy" (uptr) void))

  ;; @brief Create an op from a prepared OperationState via a plain OpBuilder.
  ;; @param builder     OpBuilder* uptr — standalone builder
  ;; @param state       OperationState* uptr — ownership NOT transferred; caller must destroy
  ;; @return            Operation* uptr of the created op, or 0 on bad input
  ;; @see               mlir/IR/Builders.h, mlir/IR/OperationSupport.h
  ;; @note              Defined in lib/Bindings/IR/OpBuilder.cpp
  (define %op-builder-create-from-state
    (foreign-procedure "mlir_ir_op_builder_create_from_state" (uptr uptr) uptr))

) ;; end library (mlir ir op-builder ffi)

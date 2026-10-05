#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir op-builder) — OpBuilder user-visible API.
;;
;; Mirrors mlir/IR/Builders.h OpBuilder.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir op-builder)
  (export
    op-builder-create
    op-builder-create-with-regions
    op-builder-at-block-end
    op-builder-destroy)
  (import (rnrs) (mlir ir op-builder ffi))

  ;; @brief mlir::OpBuilder::create — create an op via OperationState using a standalone OpBuilder.
  ;; @param builder       OpBuilder* uptr — builder positioned at the desired insertion point
  ;; @param loc-op        Operation* uptr — location source for the new op
  ;; @param op-name       Registered MLIR op name string (e.g. "arith.addi")
  ;; @param operands      Scheme list of Value* uptrs
  ;; @param result-types  Scheme list of Type* uptrs
  ;; @return              Operation* uptr of the created op, or 0 on bad input
  ;; @see                 mlir/IR/Builders.h
  ;; @note                Defined in lib/Bindings/IR/OpBuilder.cpp
  (define op-builder-create              %op-builder-create)

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
  (define op-builder-create-with-regions %op-builder-create-with-regions)

  ;; @brief Heap-allocate an mlir::OpBuilder positioned at the end of block.
  ;; @param block   Block* uptr — target block; builder is positioned at block->end()
  ;; @return        OpBuilder* uptr (heap-allocated), or 0 if block is null
  ;; @see           mlir/IR/Builders.h
  ;; @note          Defined in lib/Bindings/IR/OpBuilder.cpp; caller must free via op-builder-destroy
  (define op-builder-at-block-end        %op-builder-at-block-end)

  ;; @brief Destroy an mlir::OpBuilder created by op-builder-at-block-end.
  ;; @param builder  OpBuilder* uptr — heap-allocated builder to delete
  ;; @return         void
  ;; @see            mlir/IR/Builders.h
  ;; @note           Defined in lib/Bindings/IR/OpBuilder.cpp; no-op if builder is 0
  (define op-builder-destroy             %op-builder-destroy)

) ;; end library (mlir ir op-builder)

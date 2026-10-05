#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/Builders.h.
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir builders ffi) — raw C bindings for mlir/IR/Builders.h OpBuilder.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir builders ffi)
  (export
    %mlir::OpBuilder::create
    %mlir::OpBuilder::create-with-regions
    %mlir::OpBuilder::atBlockEnd
    %mlir::OpBuilder::~OpBuilder
    %mlir::OpBuilder::create-from-state)
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
  (define %mlir::OpBuilder::create
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
  (define %mlir::OpBuilder::create-with-regions
    (foreign-procedure "mlir_ir_op_builder_create_with_regions"
                       (uptr uptr string scheme-object scheme-object int) uptr))

  ;; @brief Heap-allocate an mlir::OpBuilder positioned at the end of block.
  ;; @param block   Block* uptr — target block; builder is positioned at block->end()
  ;; @return        OpBuilder* uptr (heap-allocated), or 0 if block is null
  ;; @see           mlir/IR/Builders.h
  ;; @note          Defined in lib/Bindings/IR/OpBuilder.cpp; caller must free via %mlir::OpBuilder::~OpBuilder
  (define %mlir::OpBuilder::atBlockEnd
    (foreign-procedure "mlir_ir_op_builder_at_block_end" (uptr) uptr))

  ;; @brief Destroy an mlir::OpBuilder created by %mlir::OpBuilder::atBlockEnd.
  ;; @param builder  OpBuilder* uptr — heap-allocated builder to delete
  ;; @return         void
  ;; @see            mlir/IR/Builders.h
  ;; @note           Defined in lib/Bindings/IR/OpBuilder.cpp; no-op if builder is 0
  (define %mlir::OpBuilder::~OpBuilder
    (foreign-procedure "mlir_ir_op_builder_destroy" (uptr) void))

  ;; @brief Create an op from a prepared OperationState via a plain OpBuilder.
  ;; @param builder     OpBuilder* uptr — standalone builder
  ;; @param state       OperationState* uptr — ownership NOT transferred; caller must destroy
  ;; @return            Operation* uptr of the created op, or 0 on bad input
  ;; @see               mlir/IR/Builders.h, mlir/IR/OperationSupport.h
  ;; @note              Defined in lib/Bindings/IR/OpBuilder.cpp
  (define %mlir::OpBuilder::create-from-state
    (foreign-procedure "mlir_ir_op_builder_create_from_state" (uptr uptr) uptr))

) ;; end library (mlir ir builders ffi)

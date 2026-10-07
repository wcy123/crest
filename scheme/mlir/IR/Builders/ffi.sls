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
;; (mlir IR Builders ffi) — raw C bindings for mlir/IR/Builders.h OpBuilder.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Builders ffi)
  (export
    %mlir::OpBuilder::atBlockEnd
    %mlir::OpBuilder::~OpBuilder
    %mlir::OpBuilder::create<OperationState>
    %mlir::OpBuilder::getContext)
  (import (rnrs) (only (chezscheme) foreign-procedure))

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
  (define %mlir::OpBuilder::create<OperationState>
    (foreign-procedure "mlir_ir_op_builder_create_from_state" (uptr uptr) uptr))

  ;; @brief Return the MLIRContext* associated with this OpBuilder.
  ;; @param builder  OpBuilder* uptr — heap-allocated builder
  ;; @return         MLIRContext* uptr
  (define %mlir::OpBuilder::getContext
    (foreign-procedure "mlir::OpBuilder::getContext" (uptr) uptr))

  ) ;; end library (mlir IR Builders ffi)

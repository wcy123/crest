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
    %mlir::OpBuilder::create<OperationState>
    %mlir::OpBuilder::createBlock
    %mlir::OpBuilder::setInsertionPoint
    %mlir::OpBuilder::getContext
    %mlir::OpBuilder::getListener
    %mlir::OpBuilder::setInsertionPointToEnd
    %mlir::OpBuilder::InsertionGuard::InsertionGuard)
  (import (rnrs)
          (crest support foreign) (only (chezscheme) foreign-procedure) (crest support BuilderBinding))

  ;; @brief Heap-allocate a CrestBox<mlir::OpBuilder> positioned at end of block.
  ;; @param ctx       MLIRContext* uptr — needed when block is not yet attached to an op
  ;; @param block     Block* uptr — target block; builder is positioned at block->end()
  ;; @param listener  raw OpBuilder::Listener* uptr, 0 for none
  ;; @return        CrestBox<OpBuilder>* uptr — freed via with-CrestObject
  ;; @see           mlir/IR/Builders.h
  (define %mlir::OpBuilder::atBlockEnd
    (crest-foreign-procedure "mlir::OpBuilder::atBlockEnd" (uptr uptr uptr) uptr))

  ;; @brief Create an op from a prepared OperationState via an OpBuilder.
  ;; @param builder     builder shell uptr
  ;; @param state       CrestBox<OperationState>* uptr
  ;; @return            Operation* uptr of the created op
  ;; @see               mlir/IR/Builders.h, mlir/IR/OperationSupport.h
  (define-builder-binding %mlir::OpBuilder::create<OperationState>
    "mlir::OpBuilder::create<OperationState>" (uptr uptr) uptr)

  ;; @brief Append a new empty block to a region, through the builder.
  ;; @param builder  builder shell uptr
  ;; @param region   Region* uptr
  ;; @return         Block* uptr, owned by the region
  (define-builder-binding %mlir::OpBuilder::createBlock
    "mlir::OpBuilder::createBlock" (uptr uptr) uptr)

  ;; @brief Return the raw OpBuilder::Listener* of a builder, 0 if none.
  ;; @param builder  builder shell uptr
  (define-builder-binding %mlir::OpBuilder::getListener
    "mlir::OpBuilder::getListener" (uptr) uptr)

  ;; @brief Return the MLIRContext* associated with this OpBuilder.
  ;; @param builder  builder shell uptr
  ;; @return         MLIRContext* uptr
  (define-builder-binding %mlir::OpBuilder::getContext
    "mlir::OpBuilder::getContext" (uptr) uptr)

  (define-builder-binding %mlir::OpBuilder::setInsertionPoint
    "mlir::OpBuilder::setInsertionPoint" (uptr uptr) void)

  ;; @brief Move the insertion point to the end of a block.
  ;; @param builder  builder shell uptr
  ;; @param block    Block* uptr
  (define-builder-binding %mlir::OpBuilder::setInsertionPointToEnd
    "mlir::OpBuilder::setInsertionPointToEnd" (uptr uptr) void)

  ;; @brief Save the builder's insertion point; freeing the shell restores it.
  ;; @param builder  builder shell uptr
  ;; @return         CrestBox<InsertionGuard>* uptr — free via with-CrestObject
  (define-builder-binding %mlir::OpBuilder::InsertionGuard::InsertionGuard
    "mlir::OpBuilder::InsertionGuard::InsertionGuard" (uptr) uptr)

  ) ;; end library (mlir IR Builders ffi)

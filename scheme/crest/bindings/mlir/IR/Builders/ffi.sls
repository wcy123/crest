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
    %mlir::OpBuilder::setInsertionPoint
    %mlir::OpBuilder::getContext
    %mlir::OpBuilder::getListener
    %crest::as_ptr<mlir::OpBuilder>)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief Heap-allocate a CrestBox<mlir::OpBuilder> positioned at end of block.
  ;; @param ctx       MLIRContext* uptr — needed when block is not yet attached to an op
  ;; @param block     Block* uptr — target block; builder is positioned at block->end()
  ;; @param listener  raw OpBuilder::Listener* uptr, 0 for none
  ;; @return        CrestBox<OpBuilder>* uptr — freed via with-CrestObject
  ;; @see           mlir/IR/Builders.h
  (define %mlir::OpBuilder::atBlockEnd
    (foreign-procedure "mlir::OpBuilder::atBlockEnd" (uptr uptr uptr) uptr))

  ;; @brief Create an op from a prepared OperationState via an OpBuilder.
  ;; @param builder     raw OpBuilder* uptr
  ;; @param state       CrestBox<OperationState>* uptr
  ;; @return            Operation* uptr of the created op
  ;; @see               mlir/IR/Builders.h, mlir/IR/OperationSupport.h
  (define %mlir::OpBuilder::create<OperationState>
    (foreign-procedure "mlir::OpBuilder::create<OperationState>" (uptr uptr) uptr))

  ;; @brief Return the raw OpBuilder::Listener* of a builder, 0 if none.
  ;; @param builder  raw OpBuilder* uptr
  (define %mlir::OpBuilder::getListener
    (foreign-procedure "mlir::OpBuilder::getListener" (uptr) uptr))

  ;; @brief Return the MLIRContext* associated with this OpBuilder.
  ;; @param builder  raw OpBuilder* uptr
  ;; @return         MLIRContext* uptr
  (define %mlir::OpBuilder::getContext
    (foreign-procedure "mlir::OpBuilder::getContext" (uptr) uptr))

  (define %mlir::OpBuilder::setInsertionPoint
    (foreign-procedure "mlir::OpBuilder::setInsertionPoint" (uptr uptr) void))

  ;; @brief Unwrap a builder shell to a raw OpBuilder*.
  ;; @param ptr  CrestBox<OpBuilder>* or CrestBox<RewriterBase*>* shell uptr
  ;; @return     raw mlir::OpBuilder* uptr
  (define %crest::as_ptr<mlir::OpBuilder>
    (foreign-procedure "crest::as_ptr<mlir::OpBuilder>" (uptr) uptr))

  ) ;; end library (mlir IR Builders ffi)

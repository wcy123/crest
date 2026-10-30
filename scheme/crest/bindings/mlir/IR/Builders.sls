#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Builders) — OpBuilder user-visible API.
;;
;; Mirrors mlir/IR/Builders.h OpBuilder.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Builders)
  (export
    mlir::OpBuilder::atBlockEnd
    mlir::OpBuilder::create<OperationState>
    mlir::OpBuilder::setInsertionPoint
    crest::isa<CrestOwned<mlir::OpBuilder>>?
    current-OpBuilder
    with-current-OpBuilder)
  (import (rnrs)
          (only (chezscheme) make-parameter parameterize)
          (mlir IR Builders ffi)
          (only (mlir IR MLIRContext) current-MLIRContext))

  ;; @brief Heap-allocate a CrestOwned<mlir::OpBuilder> positioned at end of block.
  ;; @param block   Block* uptr — target block (uses current-MLIRContext for context)
  ;; @return        CrestOwned<OpBuilder>* uptr — freed via with-CrestObject
  ;; @see           mlir/IR/Builders.h
  (define (mlir::OpBuilder::atBlockEnd block)
    (%mlir::OpBuilder::atBlockEnd (current-MLIRContext) block))

  (define mlir::OpBuilder::setInsertionPoint
    %mlir::OpBuilder::setInsertionPoint)

  (define mlir::OpBuilder::create<OperationState>
    %mlir::OpBuilder::create<OperationState>)

  ;; @brief crest::isa<CrestOwned<mlir::OpBuilder>>? — is this ptr a CrestOwned<mlir::OpBuilder>?
  ;; OpBuilder is always owned: created by with-OpBuilder or copied from
  ;; materialization callback arguments. CrestRef<OpBuilder> no longer exists.
  (define (crest::isa<CrestOwned<mlir::OpBuilder>>? ptr)
    (not (zero? (%crest::isa<CrestOwned<mlir::OpBuilder>> ptr))))

  ;; @brief current-OpBuilder — dynamic parameter holding the ambient mlir::OpBuilder* uptr.
  ;; Mirrors current-MLIRContext; see mlir/IR/Builders.h.
  (define current-OpBuilder (make-parameter #f))

  ;; @brief with-current-OpBuilder — install builder as current-OpBuilder for body forms.
  (define-syntax with-current-OpBuilder
    (syntax-rules ()
      [(_ builder body ...)
       (parameterize ([current-OpBuilder builder]) body ...)]))

  ) ;; end library (mlir IR Builders)

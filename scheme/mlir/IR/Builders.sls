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
    mlir::OpBuilder?)
  (import (rnrs)
          (mlir IR Builders ffi))

  ;; @brief Heap-allocate a CrestOwned<mlir::OpBuilder> positioned at end of block.
  ;; @param block   Block* uptr — target block
  ;; @return        CrestOwned<OpBuilder>* uptr — freed via with-CrestObject
  ;; @see           mlir/IR/Builders.h
  (define mlir::OpBuilder::atBlockEnd %mlir::OpBuilder::atBlockEnd)

  ;; @brief mlir::OpBuilder? — is this ptr an OpBuilder (owned or borrowed)?
  ;; Returns true for CrestOwned<OpBuilder>* (from atBlockEnd) and
  ;; CrestRef<OpBuilder>* (from materialization callbacks).
  (define (mlir::OpBuilder? ptr)
    (or (not (zero? (%crest::isa<CrestOwned<mlir::OpBuilder>> ptr)))
        (not (zero? (%crest::isa<CrestRef<mlir::OpBuilder>> ptr)))))

  ) ;; end library (mlir IR Builders)

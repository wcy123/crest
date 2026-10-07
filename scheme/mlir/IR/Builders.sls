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
    mlir::OpBuilder::~OpBuilder)
  (import (rnrs) (mlir IR Builders ffi))

  ;; @brief Heap-allocate an mlir::OpBuilder positioned at the end of block.
  ;; @param block   Block* uptr — target block; builder is positioned at block->end()
  ;; @return        OpBuilder* uptr (heap-allocated), or 0 if block is null
  ;; @see           mlir/IR/Builders.h
  ;; @note          Defined in lib/Bindings/IR/OpBuilder.cpp; caller must free via mlir::OpBuilder::~OpBuilder
  (define mlir::OpBuilder::atBlockEnd        %mlir::OpBuilder::atBlockEnd)

  ;; @brief Destroy an mlir::OpBuilder created by mlir::OpBuilder::atBlockEnd.
  ;; @param builder  OpBuilder* uptr — heap-allocated builder to delete
  ;; @return         void
  ;; @see            mlir/IR/Builders.h
  ;; @note           Defined in lib/Bindings/IR/OpBuilder.cpp; no-op if builder is 0
  (define mlir::OpBuilder::~OpBuilder             %mlir::OpBuilder::~OpBuilder)

  ) ;; end library (mlir IR Builders)

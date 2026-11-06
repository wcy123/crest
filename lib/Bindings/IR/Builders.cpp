/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Builders.h

#include "Builders.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"

namespace crest {

void registerIROpBuilderBindings() {
  Sregister_symbol(
      "mlir::OpBuilder::atBlockEnd",
      (void*)+[](uint64_t ctx_ptr, uint64_t block_ptr,
                 uint64_t listener_ptr) -> uint64_t {
        if (!block_ptr) {
          scheme_error("mlir::OpBuilder::atBlockEnd", "null block pointer");
        }
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__);
        auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
        // listener_ptr: raw OpBuilder::Listener*, 0 for none. A builder that
        // shares the listener of the builder that created the enclosing op
        // reports its insertions to the same driver (dialect conversion,
        // greedy rewriter).
        auto* listener =
            reinterpret_cast<mlir::OpBuilder::Listener*>(listener_ptr);
        // mlir::OpBuilder(Block*, iterator) needs the block's parent op for
        // context. For blocks in OperationState regions (not yet materialized),
        // we must supply the context explicitly via a two-step construction.
        auto* owned = new CrestBox<mlir::OpBuilder>(ctx, listener);
        owned->inner().setInsertionPoint(block, block->end());
        return reinterpret_cast<uint64_t>(owned);
      });
  Sregister_symbol(
      "mlir::OpBuilder::create<OperationState>",
      (void*)+[](uint64_t builder_ptr, uint64_t state_ptr) -> uint64_t {
        auto& builder = *crest::as_ptr<mlir::OpBuilder>(
            builder_ptr, "mlir::OpBuilder::create<OperationState>");
        auto& state = crest::CrestBox<mlir::OperationState>::inner(
            state_ptr, "mlir::OpBuilder::create<OperationState>");
        return reinterpret_cast<uint64_t>(builder.create(state));
      });
  /// builder_ptr: builder shell, op_ptr: mlir::Operation*
  Sregister_symbol(
      "mlir::OpBuilder::setInsertionPoint",
      (void*)+[](uint64_t builder_ptr, uint64_t op_ptr) -> void {
        auto& builder = *crest::as_ptr<mlir::OpBuilder>(
            builder_ptr, "mlir::OpBuilder::setInsertionPoint");
        builder.setInsertionPoint(reinterpret_cast<mlir::Operation*>(op_ptr));
      });
  // builder_ptr: builder shell. Returns the raw Listener* (0 if none).
  Sregister_symbol(
      "mlir::OpBuilder::getListener",
      (void*)+[](uint64_t builder_ptr) -> uint64_t {
        auto& builder = *crest::as_ptr<mlir::OpBuilder>(
            builder_ptr, "mlir::OpBuilder::getListener");
        return reinterpret_cast<uint64_t>(builder.getListener());
      });
  Sregister_symbol(
      "mlir::OpBuilder::getContext",
      (void*)+[](uint64_t builder_ptr) -> uint64_t {
        auto& builder = *crest::as_ptr<mlir::OpBuilder>(
            builder_ptr, "mlir::OpBuilder::getContext");
        return reinterpret_cast<uint64_t>(builder.getContext());
      });
  // builder_ptr: builder shell, block_ptr: mlir::Block*
  Sregister_symbol(
      "mlir::OpBuilder::setInsertionPointToEnd",
      (void*)+[](uint64_t builder_ptr, uint64_t block_ptr) -> void {
        if (!block_ptr) {
          scheme_error("mlir::OpBuilder::setInsertionPointToEnd",
                       "null block pointer");
        }
        auto& builder = *crest::as_ptr<mlir::OpBuilder>(
            builder_ptr, "mlir::OpBuilder::setInsertionPointToEnd");
        builder.setInsertionPointToEnd(
            reinterpret_cast<mlir::Block*>(block_ptr));
      });
  // Saves the builder's insertion point; deleting the shell restores it.
  // builder_ptr: builder shell. Returns CrestBox<InsertionGuard>* uptr.
  Sregister_symbol(
      "mlir::OpBuilder::InsertionGuard::InsertionGuard",
      (void*)+[](uint64_t builder_ptr) -> uint64_t {
        auto& builder = *crest::as_ptr<mlir::OpBuilder>(
            builder_ptr, "mlir::OpBuilder::InsertionGuard::InsertionGuard");
        return reinterpret_cast<uint64_t>(
            new CrestBox<mlir::OpBuilder::InsertionGuard>(builder));
      });
}

} // namespace crest

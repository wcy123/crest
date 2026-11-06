/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Builders.h

#include "Builders.h"
#include "../Support/BuilderBinding.h"
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
  register_builder_binding(
      "mlir::OpBuilder::create<OperationState>",
      [](mlir::OpBuilder& builder, uint64_t state_ptr) -> uint64_t {
        auto& state = crest::CrestBox<mlir::OperationState>::inner(
            state_ptr, "mlir::OpBuilder::create<OperationState>");
        return reinterpret_cast<uint64_t>(builder.create(state));
      });
  /// builder_ptr: builder shell, op_ptr: mlir::Operation*
  register_builder_binding(
      "mlir::OpBuilder::setInsertionPoint",
      [](mlir::OpBuilder& builder, uint64_t op_ptr) -> void {
        builder.setInsertionPoint(reinterpret_cast<mlir::Operation*>(op_ptr));
      });
  // builder_ptr: builder shell. Returns the raw Listener* (0 if none).
  register_builder_binding(
      "mlir::OpBuilder::getListener", [](mlir::OpBuilder& builder) -> uint64_t {
        return reinterpret_cast<uint64_t>(builder.getListener());
      });
  register_builder_binding(
      "mlir::OpBuilder::getContext", [](mlir::OpBuilder& builder) -> uint64_t {
        return reinterpret_cast<uint64_t>(builder.getContext());
      });
  // Type predicates for the builder shells: Scheme picks the binding variant by
  // the shell's type (define-builder-binding in (mlir support BuilderBinding)).
  Sregister_symbol(
      "crest::isa<CrestBox<mlir::OpBuilder>>", (void*)+[](uint64_t ptr) -> int {
        return ptr && reinterpret_cast<CrestObject*>(ptr)
                          ->isa<CrestBox<mlir::OpBuilder>>();
      });
  Sregister_symbol(
      "crest::isa<CrestBox<mlir::OpBuilder*>>",
      (void*)+[](uint64_t ptr) -> int {
        return ptr && reinterpret_cast<CrestObject*>(ptr)
                          ->isa<CrestBox<mlir::OpBuilder*>>();
      });
  // builder_ptr: builder shell, block_ptr: mlir::Block*
  register_builder_binding(
      "mlir::OpBuilder::setInsertionPointToEnd",
      [](mlir::OpBuilder& builder, uint64_t block_ptr) -> void {
        if (!block_ptr) {
          scheme_error("mlir::OpBuilder::setInsertionPointToEnd",
                       "null block pointer");
        }
        builder.setInsertionPointToEnd(
            reinterpret_cast<mlir::Block*>(block_ptr));
      });
  // Saves the builder's insertion point; deleting the shell restores it.
  // builder_ptr: builder shell. Returns CrestBox<InsertionGuard>* uptr.
  register_builder_binding(
      "mlir::OpBuilder::InsertionGuard::InsertionGuard",
      [](mlir::OpBuilder& builder) -> uint64_t {
        return reinterpret_cast<uint64_t>(
            new CrestBox<mlir::OpBuilder::InsertionGuard>(builder));
      });
}

} // namespace crest

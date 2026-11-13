/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Builders.h

#include "Builders.h"
#include "../Support/BuilderBinding.h"
#include "../Support/CrestObject.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"

namespace crest {

void registerIROpBuilderBindings() {
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-OpBuilder, which frees it after its body. A builder that is bound with
  // a plain let and never freed leaks.
  Sregister_symbol(
      "mlir::OpBuilder::atBlockEnd",
      (void*)+[](uint64_t ctx_ptr, uint64_t block_ptr,
                 uint64_t listener_ptr) -> ptr {
        if (!block_ptr) {
          return scheme_error("mlir::OpBuilder::atBlockEnd",
                              "null block pointer");
        }
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("mlir::OpBuilder::atBlockEnd",
                              "null MLIRContext pointer");
        }
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
        return Sunsigned64(reinterpret_cast<uint64_t>(owned));
      });
  register_builder_binding(
      "mlir::OpBuilder::create<OperationState>",
      [](mlir::OpBuilder& builder, uint64_t state_ptr) -> ptr {
        auto* state_box =
            crest::CrestBox<mlir::OperationState>::inner(state_ptr);
        if (!state_box) {
          return scheme_error(
              "mlir::OpBuilder::create<OperationState>",
              "null pointer or not a CrestBox<mlir::OperationState>");
        }
        auto& state = *state_box;
        return Sunsigned64(reinterpret_cast<uint64_t>(builder.create(state)));
      });
  // mlir::OpBuilder::createBlock (builder region) → Block*: a new empty block
  // at the end of the region. The block is inserted through the builder, so the
  // listener of a rewriter (dialect conversion) knows it and undoes it when the
  // conversion fails. LEAK WARNING: a block made with mlir::Block::new and
  // pushed into a region directly is unknown to the conversion, and a
  // conversion that fails leaves it behind.
  register_builder_binding(
      "mlir::OpBuilder::createBlock",
      [](mlir::OpBuilder& builder, uint64_t region_ptr) -> ptr {
        if (!region_ptr) {
          return scheme_error("mlir::OpBuilder::createBlock",
                              "region pointer is null");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            builder.createBlock(reinterpret_cast<mlir::Region*>(region_ptr))));
      });
  /// builder_ptr: builder shell, op_ptr: mlir::Operation*
  register_builder_binding(
      "mlir::OpBuilder::setInsertionPoint",
      [](mlir::OpBuilder& builder, uint64_t op_ptr) -> ptr {
        builder.setInsertionPoint(reinterpret_cast<mlir::Operation*>(op_ptr));
        return Svoid;
      });
  // builder_ptr: builder shell. Returns the raw Listener* (0 if none).
  register_builder_binding(
      "mlir::OpBuilder::getListener", [](mlir::OpBuilder& builder) -> ptr {
        return Sunsigned64(reinterpret_cast<uint64_t>(builder.getListener()));
      });
  register_builder_binding(
      "mlir::OpBuilder::getContext", [](mlir::OpBuilder& builder) -> ptr {
        return Sunsigned64(reinterpret_cast<uint64_t>(builder.getContext()));
      });
  // Type predicates for the builder shells: Scheme picks the binding variant by
  // the shell's type (define-builder-binding in (crest support
  // BuilderBinding)).
  Sregister_symbol(
      "crest::isa<CrestBox<mlir::OpBuilder>>",
      (void*)+[](uint64_t address) -> ptr {
        return Sinteger64(address && reinterpret_cast<CrestObject*>(address)
                                         ->isa<CrestBox<mlir::OpBuilder>>());
      });
  Sregister_symbol(
      "crest::isa<CrestBox<mlir::OpBuilder*>>",
      (void*)+[](uint64_t address) -> ptr {
        return Sinteger64(address && reinterpret_cast<CrestObject*>(address)
                                         ->isa<CrestBox<mlir::OpBuilder*>>());
      });
  // builder_ptr: builder shell, block_ptr: mlir::Block*
  register_builder_binding(
      "mlir::OpBuilder::setInsertionPointToEnd",
      [](mlir::OpBuilder& builder, uint64_t block_ptr) -> ptr {
        if (!block_ptr) {
          return scheme_error("mlir::OpBuilder::setInsertionPointToEnd",
                              "null block pointer");
        }
        builder.setInsertionPointToEnd(
            reinterpret_cast<mlir::Block*>(block_ptr));
        return Svoid;
      });
  // Saves the builder's insertion point; deleting the shell restores it.
  // builder_ptr: builder shell. Returns CrestBox<InsertionGuard>* uptr.
  //
  // LEAK WARNING / USE-AFTER-FREE WARNING: the box is heap memory that only
  // `with-InsertionGuard` deletes (through `with-CrestObject`), and the saved
  // insertion point is restored then. Call this binding only through that
  // macro: a raw call leaks the box, and deleting the box after the builder or
  // its block is gone makes the destructor write through a dangling builder.
  register_builder_binding(
      "mlir::OpBuilder::InsertionGuard::InsertionGuard",
      [](mlir::OpBuilder& builder) -> ptr {
        return Sunsigned64(reinterpret_cast<uint64_t>(
            new CrestBox<mlir::OpBuilder::InsertionGuard>(builder)));
      });
}

} // namespace crest

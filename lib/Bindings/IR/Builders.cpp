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
      (void*)+[](uint64_t ctx_ptr, uint64_t block_ptr) -> uint64_t {
        if (!block_ptr) {
          scheme_error("mlir::OpBuilder::atBlockEnd", "null block pointer");
        }
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__);
        auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
        // mlir::OpBuilder(Block*, iterator) needs the block's parent op for
        // context. For blocks in OperationState regions (not yet materialized),
        // we must supply the context explicitly via a two-step construction.
        auto* owned = new CrestOwned<mlir::OpBuilder>(ctx);
        owned->inner.setInsertionPoint(block, block->end());
        return reinterpret_cast<uint64_t>(owned);
      });
  Sregister_symbol(
      "mlir::OpBuilder::create<OperationState>",
      (void*)+[](uint64_t builder_ptr, uint64_t state_ptr) -> uint64_t {
        auto& builder = crest::as_ref<mlir::OpBuilder>(
            builder_ptr, "mlir::OpBuilder::create<OperationState>");
        auto& state = crest::as_ref<mlir::OperationState>(
            state_ptr, "mlir::OpBuilder::create<OperationState>");
        return reinterpret_cast<uint64_t>(builder.create(state));
      });
  /// builder_ptr: CrestOwned<mlir::OpBuilder>*, op_ptr: mlir::Operation*
  Sregister_symbol(
      "mlir::OpBuilder::setInsertionPoint",
      (void*)+[](uint64_t builder_ptr, uint64_t op_ptr) -> void {
        auto& builder = crest::as_ref<mlir::OpBuilder>(
            builder_ptr, "mlir::OpBuilder::setInsertionPoint");
        builder.setInsertionPoint(reinterpret_cast<mlir::Operation*>(op_ptr));
      });
  Sregister_symbol(
      "mlir::OpBuilder::getContext",
      (void*)+[](uint64_t builder_ptr) -> uint64_t {
        auto& builder = crest::as_ref<mlir::OpBuilder>(
            builder_ptr, "mlir::OpBuilder::getContext");
        return reinterpret_cast<uint64_t>(builder.getContext());
      });
  Sregister_symbol(
      "crest::isa<CrestOwned<mlir::OpBuilder>>",
      (void*)+[](uint64_t ptr) -> int {
        if (!ptr) {
          return 0;
        }
        return reinterpret_cast<CrestObject*>(ptr)
                       ->isa<CrestOwned<mlir::OpBuilder>>()
                   ? 1
                   : 0;
      });
}

} // namespace crest

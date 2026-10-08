/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Builders.h — OpBuilder bindings.

#include "OpBuilder.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"

namespace crest {

void registerIROpBuilderBindings() {
  Sregister_symbol(
      "mlir_ir_op_builder_at_block_end",
      (void*)+[](uint64_t block_ptr) -> uint64_t {
        if (!block_ptr) {
          scheme_error("mlir_ir_op_builder_at_block_end", "null block pointer");
        }
        auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
        return reinterpret_cast<uint64_t>(
            new CrestOwned<mlir::OpBuilder>(block, block->end()));
      });
  Sregister_symbol(
      "mlir_ir_op_builder_create_from_state",
      (void*)+[](uint64_t builder_ptr, uint64_t state_ptr) -> uint64_t {
        auto& builder = crest_owned<mlir::OpBuilder>(
            builder_ptr, "mlir_ir_op_builder_create_from_state");
        auto& state = crest_owned<mlir::OperationState>(
            state_ptr, "mlir_ir_op_builder_create_from_state");
        return reinterpret_cast<uint64_t>(builder.create(state));
      });
  Sregister_symbol(
      "mlir::OpBuilder::getContext",
      (void*)+[](uint64_t builder_ptr) -> uint64_t {
        auto& builder = crest_owned<mlir::OpBuilder>(
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

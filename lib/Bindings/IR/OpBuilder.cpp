/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Builders.h — OpBuilder bindings.

#include "OpBuilder.h"
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
            new mlir::OpBuilder(block, block->end()));
      });
  Sregister_symbol(
      "mlir_ir_op_builder_destroy", (void*)+[](uint64_t builder_ptr) -> void {
        if (!builder_ptr) {
          scheme_error("mlir_ir_op_builder_destroy", "null builder pointer");
        }
        delete reinterpret_cast<mlir::OpBuilder*>(builder_ptr);
      });
  Sregister_symbol(
      "mlir_ir_op_builder_create_from_state",
      (void*)+[](uint64_t builder_ptr, uint64_t state_ptr) -> uint64_t {
        if (!builder_ptr) {
          scheme_error("mlir_ir_op_builder_create_from_state",
                       "null builder pointer");
        }
        if (!state_ptr) {
          scheme_error("mlir_ir_op_builder_create_from_state",
                       "null state pointer");
        }
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::OpBuilder*>(builder_ptr)
                ->create(*reinterpret_cast<mlir::OperationState*>(state_ptr)));
      });
  Sregister_symbol(
      "mlir::OpBuilder::getContext",
      (void*)+[](uint64_t builder_ptr) -> uint64_t {
        if (!builder_ptr) {
          scheme_error("mlir::OpBuilder::getContext", "null builder pointer");
        }
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::OpBuilder*>(builder_ptr)->getContext());
      });
}

} // namespace crest

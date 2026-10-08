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

// Extract mlir::OpBuilder* from either CrestOwned<OpBuilder> or
// CrestRef<OpBuilder>. Returns nullptr if ptr is neither — caller must
// check/error.
static mlir::OpBuilder* extract_op_builder(uint64_t ptr) {
  auto* co = reinterpret_cast<CrestObject*>(ptr);
  if (co->isa<CrestOwned<mlir::OpBuilder>>()) {
    return &reinterpret_cast<CrestOwned<mlir::OpBuilder>*>(ptr)->inner;
  }
  if (co->isa<CrestRef<mlir::OpBuilder>>()) {
    return reinterpret_cast<CrestRef<mlir::OpBuilder>*>(ptr)->ptr;
  }
  return nullptr;
}

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
        if (!builder_ptr) {
          scheme_error("mlir_ir_op_builder_create_from_state",
                       "null builder pointer");
        }
        if (!state_ptr) {
          scheme_error("mlir_ir_op_builder_create_from_state",
                       "null state pointer");
        }
        auto* builder = extract_op_builder(builder_ptr);
        if (!builder) {
          scheme_error("mlir_ir_op_builder_create_from_state",
                       "not an OpBuilder");
        }
        auto& state =
            reinterpret_cast<CrestOwned<mlir::OperationState>*>(state_ptr)
                ->inner;
        return reinterpret_cast<uint64_t>(builder->create(state));
      });
  Sregister_symbol(
      "mlir::OpBuilder::getContext",
      (void*)+[](uint64_t builder_ptr) -> uint64_t {
        if (!builder_ptr) {
          scheme_error("mlir::OpBuilder::getContext", "null builder pointer");
        }
        auto* builder = extract_op_builder(builder_ptr);
        if (!builder) {
          scheme_error("mlir::OpBuilder::getContext", "not an OpBuilder");
        }
        return reinterpret_cast<uint64_t>(builder->getContext());
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
  Sregister_symbol(
      "crest::isa<CrestRef<mlir::OpBuilder>>", (void*)+[](uint64_t ptr) -> int {
        if (!ptr) {
          return 0;
        }
        return reinterpret_cast<CrestObject*>(ptr)
                       ->isa<CrestRef<mlir::OpBuilder>>()
                   ? 1
                   : 0;
      });
}

} // namespace crest

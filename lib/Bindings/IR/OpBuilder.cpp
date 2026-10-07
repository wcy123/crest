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

extern "C" {

// Heap-allocate an OpBuilder positioned at the end of a block.
static uint64_t mlir_ir_op_builder_at_block_end(uint64_t block_ptr) {
  if (!block_ptr) {
    scheme_error("mlir-ir-op-builder-at-block-end", "null block pointer");
    return 0; // unreachable — error performs non-local exit
  }
  auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
  return reinterpret_cast<uint64_t>(new mlir::OpBuilder(block, block->end()));
}

// Destroy an OpBuilder created by mlir_ir_op_builder_at_block_end.
static void mlir_ir_op_builder_destroy(uint64_t builder_ptr) {
  if (!builder_ptr) {
    scheme_error("mlir-ir-op-builder-destroy", "null builder pointer");
    return; // unreachable — error performs non-local exit
  }
  delete reinterpret_cast<mlir::OpBuilder*>(builder_ptr);
}

// Create an op from a prepared OperationState via a plain OpBuilder.
// Ownership of the OperationState is NOT transferred — caller must still
// destroy it with mlir_ir_operation_state_destroy.
// builder_ptr: OpBuilder* as uptr
// state_ptr:   OperationState* as uptr
// Returns: Operation* as uptr, or 0 on bad input.
static uint64_t mlir_ir_op_builder_create_from_state(uint64_t builder_ptr,
                                                     uint64_t state_ptr) {
  if (!builder_ptr) {
    scheme_error("mlir-ir-op-builder-create-from-state",
                 "null builder pointer");
    return 0; // unreachable — error performs non-local exit
  }
  if (!state_ptr) {
    scheme_error("mlir-ir-op-builder-create-from-state", "null state pointer");
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<uint64_t>(
      reinterpret_cast<mlir::OpBuilder*>(builder_ptr)
          ->create(*reinterpret_cast<mlir::OperationState*>(state_ptr)));
}

} // extern "C"

namespace crest {

void registerIROpBuilderBindings() {
  Sregister_symbol("mlir_ir_op_builder_at_block_end",
                   (void*)::mlir_ir_op_builder_at_block_end);
  Sregister_symbol("mlir_ir_op_builder_destroy",
                   (void*)::mlir_ir_op_builder_destroy);
  Sregister_symbol("mlir_ir_op_builder_create_from_state",
                   (void*)::mlir_ir_op_builder_create_from_state);
}

} // namespace crest

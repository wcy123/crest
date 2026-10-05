/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Block.h

#include "Block.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Block.h"

extern "C" {

// Get the idx-th argument of a block directly by index (no func.func walk).
// block_ptr:  Block* as uptr
// idx:        0-based argument index
// Returns: Value opaque ptr uptr, or 0 if block is null or index out of range.
uint64_t mlir_ir_block_get_argument_by_index(uint64_t block_ptr, int idx) {
  if (!block_ptr) {
    return 0;
  }
  auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
  if (idx < 0 || idx >= (int)block->getNumArguments()) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      block->getArgument(idx).getAsOpaquePointer());
}

// mlir::Block::getNumArguments — return the number of block arguments.
// block_ptr: Block* as uptr
// Returns: argument count (unsigned → uint64_t)
uint64_t mlir_ir_block_get_num_arguments(uint64_t block_ptr) {
  return reinterpret_cast<mlir::Block*>(block_ptr)->getNumArguments();
}

} // extern "C"

namespace crest {

void registerIRBlockBindings() {
  Sregister_symbol("mlir_ir_block_get_argument_by_index",
                   (void*)::mlir_ir_block_get_argument_by_index);
  Sregister_symbol("mlir_ir_block_get_num_arguments",
                   (void*)::mlir_ir_block_get_num_arguments);
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Block.h

#include "Block.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Block.h"
#include <cstdio>

extern "C" {

// Get the idx-th argument of a block directly by index (no func.func walk).
// block_ptr:  Block* as uptr
// idx:        0-based argument index
// Returns: Value opaque ptr uptr; raises Scheme error on null or out-of-range.
static uint64_t mlir_ir_block_get_argument_by_index(uint64_t block_ptr,
                                                    int idx) {
  if (!block_ptr) {
    scheme_error("mlir-ir-block-get-argument-by-index",
                 "block pointer is null");
    return 0; // unreachable — error performs non-local exit
  }
  auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
  if (idx < 0 || idx >= (int)block->getNumArguments()) {
    scheme_error("mlir-ir-block-get-argument-by-index",
                 "index out of range: idx=", idx,
                 ", num-args=", (int)block->getNumArguments());
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<uint64_t>(
      block->getArgument(idx).getAsOpaquePointer());
}

// mlir::Block::getNumArguments — return the number of block arguments.
// block_ptr: Block* as uptr
// Returns: argument count (unsigned → uint64_t)
static uint64_t mlir_ir_block_get_num_arguments(uint64_t block_ptr) {
  return reinterpret_cast<mlir::Block*>(block_ptr)->getNumArguments();
}

} // extern "C"

namespace crest {

void registerIRBlockBindings() {
  Sregister_symbol("mlir::Block::getArgument",
                   (void*)::mlir_ir_block_get_argument_by_index);
  Sregister_symbol("mlir::Block::getNumArguments",
                   (void*)::mlir_ir_block_get_num_arguments);
}

} // namespace crest

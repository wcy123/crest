/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Block.h

#include "Block.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Block.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/Types.h"
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
  }
  auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
  if (idx < 0 || idx >= (int)block->getNumArguments()) {
    scheme_error("mlir-ir-block-get-argument-by-index",
                 "index out of range: idx=", idx,
                 ", num-args=", (int)block->getNumArguments());
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

// mlir::Block::Block() — heap-allocate an empty block.
// Ownership is transferred to the region when pushed with
// mlir::Region::push_back.
static uint64_t mlir_ir_block_new() {
  return reinterpret_cast<uint64_t>(new mlir::Block());
}

// mlir::Block::addArgument(type, loc) — append one typed argument to a block.
static uint64_t mlir_ir_block_add_argument(uint64_t block_ptr,
                                           uint64_t type_ptr,
                                           uint64_t loc_ptr) {
  if (!block_ptr) {
    scheme_error("mlir::Block::addArgument", "block pointer is null");
    return 0;
  }
  auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
  auto type =
      mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(type_ptr));
  auto loc = mlir::Location::getFromOpaquePointer(
      reinterpret_cast<const void*>(loc_ptr));
  mlir::BlockArgument arg = block->addArgument(type, loc);
  return reinterpret_cast<uint64_t>(
      const_cast<void*>(arg.getAsOpaquePointer()));
}

} // extern "C"

namespace crest {

void registerIRBlockBindings() {
  Sregister_symbol("mlir::Block::getArgument",
                   (void*)::mlir_ir_block_get_argument_by_index);
  Sregister_symbol("mlir::Block::getNumArguments",
                   (void*)::mlir_ir_block_get_num_arguments);
  Sregister_symbol("mlir::Block::new", (void*)::mlir_ir_block_new);
  Sregister_symbol("mlir::Block::addArgument",
                   (void*)::mlir_ir_block_add_argument);
}

} // namespace crest

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

namespace crest {

void registerIRBlockBindings() {
  Sregister_symbol(
      "mlir::Block::getArgument",
      (void*)+[](uint64_t block_ptr, int idx) -> uint64_t {
        if (!block_ptr) {
          scheme_error("mlir::Block::getArgument", "block pointer is null");
        }
        auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
        if (idx < 0 || idx >= (int)block->getNumArguments()) {
          scheme_error("mlir::Block::getArgument",
                       "index out of range: idx=", idx,
                       ", num-args=", (int)block->getNumArguments());
        }
        return reinterpret_cast<uint64_t>(
            block->getArgument(idx).getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::Block::getNumArguments",
      (void*)+[](uint64_t block_ptr) -> uint64_t {
        return reinterpret_cast<mlir::Block*>(block_ptr)->getNumArguments();
      });
  Sregister_symbol(
      "mlir::Block::new", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(new mlir::Block());
      });
  Sregister_symbol(
      "mlir::Block::addArgument",
      (void*)+[](uint64_t block_ptr, uint64_t type_ptr,
                 uint64_t loc_ptr) -> uint64_t {
        if (!block_ptr) {
          scheme_error("mlir::Block::addArgument", "block pointer is null");
          return 0;
        }
        auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        mlir::BlockArgument arg = block->addArgument(type, loc);
        return reinterpret_cast<uint64_t>(
            const_cast<void*>(arg.getAsOpaquePointer()));
      });
}

} // namespace crest

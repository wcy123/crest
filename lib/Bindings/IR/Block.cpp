/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Block.h

#include "Block.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Block.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/Types.h"

namespace crest {

void registerIRBlockBindings() {
  register_binding(
      "mlir::Block::getArgument",
      [](uint64_t block_ptr, int idx) -> llvm::Expected<uint64_t> {
        if (!block_ptr) {
          return fail("mlir::Block::getArgument", "block pointer is null");
        }
        auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
        if (idx < 0 || idx >= (int)block->getNumArguments()) {
          return fail(
              "mlir::Block::getArgument",
              "index out of range: idx=" + llvm::Twine(idx) +
                  ", num-args=" + llvm::Twine(block->getNumArguments()));
        }
        return reinterpret_cast<uint64_t>(
            block->getArgument(static_cast<unsigned>(idx))
                .getAsOpaquePointer());
      });
  register_binding(
      "mlir::Block::getNumArguments", [](uint64_t block_ptr) -> uint64_t {
        return reinterpret_cast<mlir::Block*>(block_ptr)->getNumArguments();
      });
  // LEAK WARNING: the block belongs to nobody. A block that is never added to a
  // region and never erased leaks.
  register_binding("mlir::Block::new", []() -> uint64_t {
    return reinterpret_cast<uint64_t>(new mlir::Block());
  });
  register_binding("mlir::Block::addArgument",
                   [](uint64_t block_ptr, uint64_t type_ptr,
                      uint64_t loc_ptr) -> llvm::Expected<uint64_t> {
                     if (!block_ptr) {
                       return fail("mlir::Block::addArgument",
                                   "block pointer is null");
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

  register_binding("mlir::Block::empty", [](uint64_t block_ptr) -> int {
    if (!block_ptr) {
      return 1;
    }
    auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
    return block->empty() ? 1 : 0;
  });

  register_binding("mlir::Block::back", [](uint64_t block_ptr) -> uint64_t {
    if (!block_ptr) {
      return 0;
    }
    auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
    if (block->empty()) {
      return 0;
    }
    return reinterpret_cast<uint64_t>(&block->back());
  });

  register_binding("mlir::Block::front", [](uint64_t block_ptr) -> uint64_t {
    if (!block_ptr) {
      return 0;
    }
    auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
    if (block->empty()) {
      return 0;
    }
    return reinterpret_cast<uint64_t>(&block->front());
  });
}

} // namespace crest

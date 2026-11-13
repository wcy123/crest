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
  Sregister_symbol(
      "mlir::Block::getArgument",
      (void*)+[](uint64_t block_ptr, int idx) -> ptr {
        if (!block_ptr) {
          return scheme_error("mlir::Block::getArgument",
                              "block pointer is null");
        }
        auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
        if (idx < 0 || idx >= (int)block->getNumArguments()) {
          return scheme_error(
              "mlir::Block::getArgument",
              llvm::Twine("index out of range: idx=") + llvm::Twine(idx) +
                  ", num-args=" + llvm::Twine(block->getNumArguments()));
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            block->getArgument(static_cast<unsigned>(idx))
                .getAsOpaquePointer()));
      });
  Sregister_symbol(
      "mlir::Block::getNumArguments", (void*)+[](uint64_t block_ptr) -> ptr {
        if (!block_ptr) {
          return scheme_error("mlir::Block::getNumArguments",
                              "block pointer is null");
        }
        return Sunsigned64(
            reinterpret_cast<mlir::Block*>(block_ptr)->getNumArguments());
      });
  // LEAK WARNING: the block belongs to nobody. A block that is never added to a
  // region and never erased leaks.
  Sregister_symbol(
      "mlir::Block::new", (void*)+[]() -> ptr {
        return Sunsigned64(reinterpret_cast<uint64_t>(new mlir::Block()));
      });
  Sregister_symbol(
      "mlir::Block::addArgument",
      (void*)+[](uint64_t block_ptr, uint64_t type_ptr,
                 uint64_t loc_ptr) -> ptr {
        if (!block_ptr) {
          return scheme_error("mlir::Block::addArgument",
                              "block pointer is null");
        }
        auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        mlir::BlockArgument arg = block->addArgument(type, loc);
        return Sunsigned64(reinterpret_cast<uint64_t>(
            const_cast<void*>(arg.getAsOpaquePointer())));
      });

  Sregister_symbol(
      "mlir::Block::empty", (void*)+[](uint64_t block_ptr) -> ptr {
        if (!block_ptr) {
          return Sinteger64(1);
        }
        auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
        return Sinteger64(block->empty() ? 1 : 0);
      });

  Sregister_symbol(
      "mlir::Block::back", (void*)+[](uint64_t block_ptr) -> ptr {
        if (!block_ptr) {
          return Sunsigned64(0);
        }
        auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
        if (block->empty()) {
          return Sunsigned64(0);
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(&block->back()));
      });

  Sregister_symbol(
      "mlir::Block::front", (void*)+[](uint64_t block_ptr) -> ptr {
        if (!block_ptr) {
          return Sunsigned64(0);
        }
        auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
        if (block->empty()) {
          return Sunsigned64(0);
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(&block->front()));
      });
}

} // namespace crest

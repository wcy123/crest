/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Region.h

#include "Region.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Block.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Region.h"

namespace crest {

void registerIRRegionBindings() {
  register_binding("mlir::Region::push_back",
                   [](uint64_t region_ptr, uint64_t block_ptr) -> llvm::Error {
                     if (!region_ptr) {
                       return fail("mlir::Region::push_back",
                                   llvm::Twine("region pointer is null"));
                       return llvm::Error::success();
                     }
                     reinterpret_cast<mlir::Region*>(region_ptr)
                         ->push_back(reinterpret_cast<mlir::Block*>(block_ptr));
                     return llvm::Error::success();
                   });
  register_binding(
      "mlir::Region::getParentOp",
      [](uint64_t region_ptr) -> llvm::Expected<uint64_t> {
        if (!region_ptr) {
          return fail("mlir::Region::getParentOp",
                      llvm::Twine("region pointer is null"));
          return 0;
        }
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::Region*>(region_ptr)->getParentOp());
      });
  register_binding("mlir::Region::front",
                   [](uint64_t region_ptr) -> llvm::Expected<uint64_t> {
                     if (!region_ptr) {
                       return fail("mlir::Region::front",
                                   llvm::Twine("region pointer is null"));
                       return 0;
                     }
                     auto* region = reinterpret_cast<mlir::Region*>(region_ptr);
                     if (region->empty()) {
                       return 0;
                     }
                     return reinterpret_cast<uint64_t>(&region->front());
                   });

  register_binding("mlir::Region::emplaceBlock",
                   [](uint64_t region_ptr) -> uint64_t {
                     if (!region_ptr) {
                       return 0;
                     }
                     auto* region = reinterpret_cast<mlir::Region*>(region_ptr);
                     auto* block = new mlir::Block();
                     region->push_back(block);
                     return reinterpret_cast<uint64_t>(block);
                   });
}

} // namespace crest

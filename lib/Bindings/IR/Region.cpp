/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Region.h

#include "Region.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Block.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Region.h"

namespace crest {

void registerIRRegionBindings() {
  Sregister_symbol(
      "mlir::Region::push_back",
      (void*)+[](uint64_t region_ptr, uint64_t block_ptr) -> void {
        if (!region_ptr) {
          scheme_error("mlir::Region::push_back", "region pointer is null");
          return;
        }
        reinterpret_cast<mlir::Region*>(region_ptr)
            ->push_back(reinterpret_cast<mlir::Block*>(block_ptr));
      });
  Sregister_symbol(
      "mlir::Region::getParentOp", (void*)+[](uint64_t region_ptr) -> uint64_t {
        if (!region_ptr) {
          scheme_error("mlir::Region::getParentOp", "region pointer is null");
          return 0;
        }
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::Region*>(region_ptr)->getParentOp());
      });
  Sregister_symbol(
      "mlir::Region::front", (void*)+[](uint64_t region_ptr) -> uint64_t {
        if (!region_ptr) {
          scheme_error("mlir::Region::front", "region pointer is null");
          return 0;
        }
        auto* region = reinterpret_cast<mlir::Region*>(region_ptr);
        if (region->empty()) {
          return 0;
        }
        return reinterpret_cast<uint64_t>(&region->front());
      });
}

} // namespace crest

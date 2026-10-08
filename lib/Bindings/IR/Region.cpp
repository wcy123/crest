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

extern "C" {

// mlir::Region::push_back(Block*) — append a heap-allocated block to a region.
static void mlir_ir_region_push_back(uint64_t region_ptr, uint64_t block_ptr) {
  if (!region_ptr) {
    scheme_error("mlir::Region::push_back", "region pointer is null");
    return;
  }
  reinterpret_cast<mlir::Region*>(region_ptr)
      ->push_back(reinterpret_cast<mlir::Block*>(block_ptr));
}

// mlir::Region::getParentOp() — return the operation that contains this region.
static uint64_t mlir_ir_region_get_parent_op(uint64_t region_ptr) {
  if (!region_ptr) {
    scheme_error("mlir::Region::getParentOp", "region pointer is null");
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      reinterpret_cast<mlir::Region*>(region_ptr)->getParentOp());
}

// mlir::Region::front() — return the first Block, or 0 if empty.
static uint64_t mlir_ir_region_get_first_block(uint64_t region_ptr) {
  if (!region_ptr) {
    scheme_error("mlir::Region::front", "region pointer is null");
    return 0;
  }
  auto* region = reinterpret_cast<mlir::Region*>(region_ptr);
  if (region->empty()) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(&region->front());
}

} // extern "C"

namespace crest {

void registerIRRegionBindings() {
  Sregister_symbol("mlir::Region::push_back",
                   (void*)::mlir_ir_region_push_back);
  Sregister_symbol("mlir::Region::getParentOp",
                   (void*)::mlir_ir_region_get_parent_op);
  Sregister_symbol("mlir::Region::front",
                   (void*)::mlir_ir_region_get_first_block);
}

} // namespace crest

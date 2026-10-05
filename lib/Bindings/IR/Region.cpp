/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Region.h

#include "Region.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Block.h"
#include "mlir/IR/Region.h"

extern "C" {

// Append a new Block to a region with typed arguments.
uint64_t mlir_ir_region_append_new_block(uint64_t region_ptr,
                                         ptr arg_types_list) {
  if (!region_ptr) {
    return 0;
  }
  auto* region = reinterpret_cast<mlir::Region*>(region_ptr);
  auto* block = new mlir::Block();
  region->push_back(block);
  mlir::Location loc = region->getParentOp()->getLoc();
  for (ptr cur = static_cast<ptr>(arg_types_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      break;
    }
    block->addArgument(
        mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))),
        loc);
  }
  return reinterpret_cast<uint64_t>(block);
}

// Return the first Block of a region, or 0 if the region is null or empty.
// Mirrors Region::front().
uint64_t mlir_ir_region_get_first_block(uint64_t region_ptr) {
  if (!region_ptr) {
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
  Sregister_symbol("mlir_ir_region_append_new_block",
                   (void*)::mlir_ir_region_append_new_block);
  Sregister_symbol("mlir_ir_region_get_first_block",
                   (void*)::mlir_ir_region_get_first_block);
}

} // namespace crest

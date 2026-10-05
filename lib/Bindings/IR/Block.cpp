/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Block.h

#include "Block.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/Block.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Region.h"

extern "C" {

// Walk up from op to find the enclosing func.func and return its index-th
// block argument as a raw opaque Value pointer.
ptr mlir_ir_block_get_argument(ptr op_ptr, int index) {
  if (!op_ptr) {
    return nullptr;
  }
  mlir::Operation* op = static_cast<mlir::Operation*>(op_ptr);
  while (op && !llvm::isa<mlir::func::FuncOp>(op)) {
    op = op->getParentOp();
  }
  if (!op) {
    return nullptr;
  }
  auto funcOp = llvm::cast<mlir::func::FuncOp>(op);
  if (index < 0 || index >= (int)funcOp.getNumArguments()) {
    return nullptr;
  }
  return const_cast<void*>(funcOp.getArgument(index).getAsOpaquePointer());
}

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

} // extern "C"

namespace crest {

void registerIRBlockBindings() {
  Sregister_symbol("mlir_ir_block_get_argument",
                   (void*)::mlir_ir_block_get_argument);
  Sregister_symbol("mlir_ir_block_get_argument_by_index",
                   (void*)::mlir_ir_block_get_argument_by_index);
  Sregister_symbol("mlir_ir_region_append_new_block",
                   (void*)::mlir_ir_region_append_new_block);
}

} // namespace crest

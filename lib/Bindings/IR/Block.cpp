/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Block.h

#include "Block.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/Operation.h"

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

} // extern "C"

namespace crest {

void registerIRBlockBindings() {
  Sregister_symbol("mlir_ir_block_get_argument",
                   (void*)::mlir_ir_block_get_argument);
}

} // namespace crest

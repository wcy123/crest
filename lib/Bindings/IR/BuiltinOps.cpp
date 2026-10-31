/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/BuiltinOps.h

#include "BuiltinOps.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/BuiltinOps.h"

namespace crest {

void registerIRBuiltinOpsBindings() {

  Sregister_symbol(
      "mlir::ModuleOp::create", (void*)+[](uint64_t loc_ptr) -> uint64_t {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        return reinterpret_cast<uint64_t>(
            mlir::ModuleOp::create(loc).getOperation());
      });

  // Identity: mlir::ModuleOp::create already returns Operation*.
  Sregister_symbol(
      "mlir::ModuleOp::getOperation",
      (void*)+[](uint64_t op_ptr) -> uint64_t { return op_ptr; });

  Sregister_symbol(
      "mlir::ModuleOp::getBody", (void*)+[](uint64_t op_ptr) -> uint64_t {
        if (!op_ptr) {
          return 0;
        }
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return reinterpret_cast<uint64_t>(
            mlir::cast<mlir::ModuleOp>(op).getBody());
      });
}

} // namespace crest

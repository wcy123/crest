/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/BuiltinOps.h

#include "BuiltinOps.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/BuiltinOps.h"

namespace crest {

void registerIRBuiltinOpsBindings() {

  // LEAK WARNING: the module belongs to nobody. The caller must erase it, for
  // example with with-mlir::OwningOpRef; a module that is never erased leaks.
  Sregister_symbol(
      "mlir::ModuleOp::create", (void*)+[](uint64_t loc_ptr) -> ptr {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::ModuleOp::create(loc).getOperation()));
      });

  // Identity: mlir::ModuleOp::create already returns Operation*.
  Sregister_symbol(
      "mlir::ModuleOp::getOperation",
      (void*)+[](uint64_t op_ptr) -> ptr { return Sunsigned64(op_ptr); });

  Sregister_symbol(
      "mlir::ModuleOp::getBody", (void*)+[](uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return Sunsigned64(0);
        }
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::cast<mlir::ModuleOp>(op).getBody()));
      });
}

} // namespace crest

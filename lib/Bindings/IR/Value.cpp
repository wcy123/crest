/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors (mlir ir value): mlir/IR/Value.h

#include "mlir/IR/Value.h"
#include "Support/SchemeWrapper.h"
#include "mlir/CAPI/IR.h"
#include "mlir/CAPI/Wrap.h"
#include "mlir/IR/Operation.h"

namespace crest {

void registerIRValueBindings() {
  Sregister_symbol(
      "mlir::Value::getDefiningOp", (void*)+[](uint64_t value) -> uint64_t {
        if (!value) {
          scheme_error("mlir::Value::getDefiningOp", "value pointer is null");
        }
        MlirValue cVal{reinterpret_cast<const void*>(value)};
        return reinterpret_cast<uint64_t>(unwrap(cVal).getDefiningOp());
      });
  Sregister_symbol(
      "mlir::isa<BlockArgument>", (void*)+[](uint64_t value) -> int {
        if (!value) {
          scheme_error("mlir::isa<BlockArgument>", "value pointer is null");
        }
        mlir::Value val =
            unwrap(MlirValue{reinterpret_cast<const void*>(value)});
        return mlir::isa<mlir::BlockArgument>(val) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir::Value::getUses", (void*)+[](uint64_t val_ptr) -> uint64_t {
        if (!val_ptr) {
          scheme_error("mlir::Value::getUses", "value pointer is null");
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(val_ptr));
        return static_cast<uint64_t>(
            std::distance(val.use_begin(), val.use_end()));
      });
  Sregister_symbol(
      "mlir::Value::getType", (void*)+[](uint64_t value_ptr) -> uint64_t {
        if (!value_ptr) {
          scheme_error("mlir::Value::getType", "value pointer is null");
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value_ptr));
        return reinterpret_cast<uint64_t>(val.getType().getAsOpaquePointer());
      });
  // Alias with ? suffix (Scheme predicate convention)
  Sregister_symbol(
      "mlir::isa<BlockArgument>?", (void*)+[](uint64_t value) -> int {
        if (!value) {
          scheme_error("mlir::isa<BlockArgument>?", "value pointer is null");
        }
        mlir::Value val =
            unwrap(MlirValue{reinterpret_cast<const void*>(value)});
        return mlir::isa<mlir::BlockArgument>(val) ? 1 : 0;
      });
}

} // namespace crest

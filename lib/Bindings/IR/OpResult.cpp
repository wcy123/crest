/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Value.h — mlir::OpResult bindings.

#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Value.h"

namespace crest {

void registerIROpResultBindings() {
  Sregister_symbol(
      "mlir::OpResult::getResultNumber",
      (void*)+[](uint64_t value) -> uint64_t {
        if (!value) {
          scheme_error("mlir::OpResult::getResultNumber",
                       "value must not be null");
        }
        auto val = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value));
        auto result = mlir::dyn_cast<mlir::OpResult>(val);
        if (!result) {
          scheme_error("mlir::OpResult::getResultNumber",
                       "value is not an OpResult");
        }
        return static_cast<uint64_t>(result.getResultNumber());
      });
}

} // namespace crest

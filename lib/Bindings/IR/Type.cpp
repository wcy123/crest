/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Types.h — mlir::Type base class bindings.

#include "Type.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Types.h"

extern "C" {} // extern "C"

namespace crest {

void registerIRTypeBindings() {
  Sregister_symbol(
      "mlir::Type::getContext", (void*)+[](uint64_t type_ptr) -> uint64_t {
        if (!type_ptr) {
          scheme_error("mlir::Type::getContext", "type pointer is null");
        }
        return reinterpret_cast<uint64_t>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr))
                .getContext());
      });
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Types.h — mlir::Type base class bindings.

#include "Type.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Types.h"

extern "C" {

// mlir::Type::getContext() → MLIRContext*
static uint64_t mlir_ir_type_get_context(uint64_t type_ptr) {
  if (!type_ptr) {
    scheme_error("mlir-ir-type-get-context", "type pointer is null");
  }
  return reinterpret_cast<uint64_t>(
      mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(type_ptr))
          .getContext());
}

} // extern "C"

namespace crest {

void registerIRTypeBindings() {
  Sregister_symbol("mlir::Type::getContext", (void*)::mlir_ir_type_get_context);
}

} // namespace crest

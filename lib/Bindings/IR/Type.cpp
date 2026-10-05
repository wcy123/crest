/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Types.h — mlir::Type base class bindings.

#include "Type.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Types.h"

static void scheme_error(const char* who, const char* msg) {
  Scall2(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring(msg));
}

extern "C" {

// mlir::Type::getContext() → MLIRContext*
uint64_t mlir_ir_type_get_context(uint64_t type_ptr) {
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
  Sregister_symbol("mlir_ir_type_get_context",
                   (void*)::mlir_ir_type_get_context);
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Value.h — mlir::OpResult bindings.

#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Value.h"

static void scheme_error(const char* who, const char* msg) {
  Scall2(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring(msg));
}

extern "C" {

// mlir::OpResult::getResultNumber()
static uint64_t mlir_ir_op_result_get_result_number(uint64_t value) {
  if (!value) {
    scheme_error("mlir-ir-op-result-get-result-number",
                 "value must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  auto val =
      mlir::Value::getFromOpaquePointer(reinterpret_cast<const void*>(value));
  auto result = mlir::dyn_cast<mlir::OpResult>(val);
  if (!result) {
    scheme_error("mlir-ir-op-result-get-result-number",
                 "value is not an OpResult");
    return 0; // unreachable — error performs non-local exit
  }
  return static_cast<uint64_t>(result.getResultNumber());
}

} // extern "C"

namespace crest {

void registerIROpResultBindings() {
  Sregister_symbol("mlir::OpResult::getResultNumber",
                   (void*)::mlir_ir_op_result_get_result_number);
}

} // namespace crest

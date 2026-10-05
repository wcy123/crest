/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Value.h — mlir::OpResult bindings.

#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Value.h"

extern "C" {

// mlir::OpResult::getResultNumber()
uint64_t mlir_ir_op_result_get_result_number(uint64_t value) {
  if (!value) {
    return 0;
  }
  auto val =
      mlir::Value::getFromOpaquePointer(reinterpret_cast<const void*>(value));
  auto result = mlir::dyn_cast<mlir::OpResult>(val);
  if (!result) {
    return 0;
  }
  return static_cast<uint64_t>(result.getResultNumber());
}

} // extern "C"

namespace crest {

void registerIROpResultBindings() {
  Sregister_symbol("mlir_ir_op_result_get_result_number",
                   (void*)::mlir_ir_op_result_get_result_number);
  // Backward-compat alias for the misnamed mlir_ir_value_get_result_number
  Sregister_symbol("mlir_ir_value_get_result_number",
                   (void*)::mlir_ir_op_result_get_result_number);
}

} // namespace crest

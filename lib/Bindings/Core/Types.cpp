/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Backward-compatibility shim. Canonical implementations have moved to:
//   lib/Bindings/IR/BuiltinTypes.cpp  (mlir_ir_builtin_types_*)
//   lib/Bindings/IR/Type.cpp          (mlir_ir_type_*)

#include "Types.h"
#include "../IR/BuiltinTypes.h"
#include "../IR/Type.h"
#include "../Support/SchemeWrapper.h"
#include <cstdint>

// Forward declarations of canonical C functions defined in other TUs.
extern "C" {
uint64_t mlir_ir_type_get_context(uint64_t);
uint64_t mlir_ir_builtin_types_index_type_get(uint64_t);
uint64_t mlir_ir_builtin_types_integer_type_get_i64(uint64_t);
uint64_t mlir_ir_builtin_types_integer_type_get_i1(uint64_t);
int mlir_ir_builtin_types_ranked_tensor_type_isa(uint64_t);
int64_t mlir_ir_builtin_types_ranked_tensor_type_get_rank(uint64_t);
uint64_t mlir_ir_builtin_types_ranked_tensor_type_get_element_type(uint64_t);
ptr mlir_ir_builtin_types_ranked_tensor_type_get_shape(ptr);
uint64_t mlir_ir_builtin_types_ranked_tensor_type_get_encoding(uint64_t);
uint64_t mlir_ir_builtin_types_ranked_tensor_type_clone_with_encoding(uint64_t,
                                                                      uint64_t);
} // extern "C"

namespace crest {

void registerTypeBindings() {
  registerIRTypeBindings();
  registerIRBuiltinTypesBindings();

  // Old names — kept for backward compatibility.
  Sregister_symbol("mlir_type_get_context", (void*)mlir_ir_type_get_context);
  Sregister_symbol("mlir_get_index_type",
                   (void*)mlir_ir_builtin_types_index_type_get);
  Sregister_symbol("mlir_get_i64_type",
                   (void*)mlir_ir_builtin_types_integer_type_get_i64);
  Sregister_symbol("mlir_get_i1_type",
                   (void*)mlir_ir_builtin_types_integer_type_get_i1);
  Sregister_symbol("mlir_type_is_ranked_tensor",
                   (void*)mlir_ir_builtin_types_ranked_tensor_type_isa);
  Sregister_symbol("mlir_type_get_rank",
                   (void*)mlir_ir_builtin_types_ranked_tensor_type_get_rank);
  Sregister_symbol(
      "mlir_type_get_element_type",
      (void*)mlir_ir_builtin_types_ranked_tensor_type_get_element_type);
  Sregister_symbol("mlir_type_get_shape",
                   (void*)mlir_ir_builtin_types_ranked_tensor_type_get_shape);
  Sregister_symbol(
      "mlir_type_get_encoding",
      (void*)mlir_ir_builtin_types_ranked_tensor_type_get_encoding);
  Sregister_symbol(
      "mlir_tensor_type_with_encoding",
      (void*)mlir_ir_builtin_types_ranked_tensor_type_clone_with_encoding);
  Sregister_symbol(
      "mlir_ranked_tensor_type_get_encoding",
      (void*)mlir_ir_builtin_types_ranked_tensor_type_get_encoding);
  Sregister_symbol(
      "mlir_ranked_tensor_type_with_encoding",
      (void*)mlir_ir_builtin_types_ranked_tensor_type_clone_with_encoding);
}

} // namespace crest

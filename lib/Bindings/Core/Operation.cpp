/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Backward-compatibility shim. Canonical implementations moved to:
//   lib/Bindings/IR/Operation.cpp
//   lib/Bindings/IR/Block.cpp
//   lib/Bindings/Interfaces/DestinationStyleOp.cpp

#include "Operation.h"
#include "../IR/Block.h"
#include "../IR/Operation.h"
#include "../Interfaces/DestinationStyleOp.h"
#include "../Support/SchemeWrapper.h"
#include <cstdint>

// Forward declarations of C functions defined in IR/Operation.cpp,
// IR/Block.cpp, and Interfaces/DestinationStyleOp.cpp.
extern "C" {
const char* mlir_ir_operation_get_name(uint64_t);
uint64_t mlir_ir_operation_get_context(uint64_t);
int64_t mlir_ir_operation_get_num_operands(uint64_t);
int64_t mlir_ir_operation_get_num_results(uint64_t);
uint64_t mlir_ir_operation_get_op_operand(uint64_t, int64_t);
uint64_t mlir_ir_operation_get_result(uint64_t, int64_t);
void* mlir_ir_operation_get_parent_op(void*);
void* mlir_ir_op_operand_get_value(void*, int);
void* mlir_ir_op_result_get_value(void*, int);
void* mlir_ir_operation_get_loc(void*);
void mlir_ir_operation_walk(uint64_t, void*);
void mlir_ir_operation_set_operand(uint64_t, int, uint64_t);
int mlir_ir_operation_use_empty(uint64_t);
const char* mlir_ir_operation_get_string_attr(uint64_t, const char*);
int64_t mlir_ir_operation_get_integer_attr(uint64_t, const char*, int64_t);
void* mlir_ir_operation_get_integer_array_attr(uint64_t, const char*);
void mlir_ir_operation_set_f32_attr(uint64_t, const char*, double);
void mlir_ir_operation_set_i64_attr(uint64_t, const char*, int64_t);
void mlir_ir_operation_set_unit_attr(uint64_t, const char*);
void mlir_ir_operation_set_index_attr(uint64_t, const char*, int64_t);
void mlir_ir_operation_set_dense_i64_array(uint64_t, const char*, void*);
void mlir_ir_operation_set_i64_array_attr(uint64_t, const char*, void*);
void mlir_ir_operation_set_dense_i32_array(uint64_t, const char*, void*);
void mlir_ir_operation_copy_attr(uint64_t, const char*, uint64_t, const char*);
int mlir_ir_operation_has_attr(uint64_t, const char*);
void mlir_ir_operation_emit_error(uint64_t, const char*);
void mlir_ir_operation_emit_warning(uint64_t, const char*);
void mlir_ir_operation_emit_remark(uint64_t, const char*);
void mlir_ir_operation_erase(uint64_t);
void* mlir_ir_block_get_argument(void*, int);
int mlir_interfaces_dps_get_num_dps_inits(uint64_t);
uint64_t mlir_interfaces_dps_get_dps_init_value(uint64_t, int);
} // extern "C"

namespace crest {

void registerOperationBindings() {
  registerIROperationBindings();
  registerIRBlockBindings();
  registerInterfacesDpsBindings();

  // Old names — kept for backward compatibility with existing Scheme code.
  Sregister_symbol("mlir_operation_get_name",
                   (void*)::mlir_ir_operation_get_name);
  Sregister_symbol("mlir_operation_get_context",
                   (void*)::mlir_ir_operation_get_context);
  Sregister_symbol("mlir_operation_num_operands",
                   (void*)::mlir_ir_operation_get_num_operands);
  Sregister_symbol("mlir_operation_num_results",
                   (void*)::mlir_ir_operation_get_num_results);
  Sregister_symbol("mlir_operation_get_operand",
                   (void*)::mlir_ir_operation_get_op_operand);
  Sregister_symbol("mlir_operation_get_result",
                   (void*)::mlir_ir_operation_get_result);
  Sregister_symbol("mlir_operation_get_parent",
                   (void*)::mlir_ir_operation_get_parent_op);
  Sregister_symbol("mlir_operation_get_operand_value",
                   (void*)::mlir_ir_op_operand_get_value);
  Sregister_symbol("mlir_operation_get_result_value",
                   (void*)::mlir_ir_op_result_get_value);
  Sregister_symbol("mlir_operation_get_loc",
                   (void*)::mlir_ir_operation_get_loc);
  Sregister_symbol("mlir_operation_get_block_argument",
                   (void*)::mlir_ir_block_get_argument);
  Sregister_symbol("mlir_operation_walk", (void*)::mlir_ir_operation_walk);
  Sregister_symbol("mlir_operation_num_dps_inits",
                   (void*)::mlir_interfaces_dps_get_num_dps_inits);
  Sregister_symbol("mlir_operation_get_dps_init_value",
                   (void*)::mlir_interfaces_dps_get_dps_init_value);
  Sregister_symbol("mlir_operation_set_operand",
                   (void*)::mlir_ir_operation_set_operand);
  Sregister_symbol("mlir_operation_use_empty",
                   (void*)::mlir_ir_operation_use_empty);
  Sregister_symbol("mlir_operation_get_string_attr",
                   (void*)::mlir_ir_operation_get_string_attr);
  Sregister_symbol("mlir_operation_get_integer_attr",
                   (void*)::mlir_ir_operation_get_integer_attr);
  Sregister_symbol("mlir_operation_get_integer_array_attr",
                   (void*)::mlir_ir_operation_get_integer_array_attr);
  Sregister_symbol("mlir_operation_set_f32_attr",
                   (void*)::mlir_ir_operation_set_f32_attr);
  Sregister_symbol("mlir_operation_set_i64_attr",
                   (void*)::mlir_ir_operation_set_i64_attr);
  Sregister_symbol("mlir_operation_set_unit_attr",
                   (void*)::mlir_ir_operation_set_unit_attr);
  Sregister_symbol("mlir_operation_set_index_attr",
                   (void*)::mlir_ir_operation_set_index_attr);
  Sregister_symbol("mlir_operation_set_dense_i64_array",
                   (void*)::mlir_ir_operation_set_dense_i64_array);
  Sregister_symbol("mlir_operation_set_i64_array_attr",
                   (void*)::mlir_ir_operation_set_i64_array_attr);
  Sregister_symbol("mlir_operation_set_dense_i32_array",
                   (void*)::mlir_ir_operation_set_dense_i32_array);
  Sregister_symbol("mlir_operation_copy_attr",
                   (void*)::mlir_ir_operation_copy_attr);
  Sregister_symbol("mlir_operation_has_attr",
                   (void*)::mlir_ir_operation_has_attr);
  Sregister_symbol("mlir_emit_error", (void*)::mlir_ir_operation_emit_error);
  Sregister_symbol("mlir_emit_warning",
                   (void*)::mlir_ir_operation_emit_warning);
  Sregister_symbol("mlir_emit_remark", (void*)::mlir_ir_operation_emit_remark);
  Sregister_symbol("mlir_op_erase", (void*)::mlir_ir_operation_erase);
}

} // namespace crest

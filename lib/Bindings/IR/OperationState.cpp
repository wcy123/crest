/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/OperationSupport.h

// Thin C wrappers around mlir::OperationState (heap-allocated for FFI
// stability). Exposes per-element operand/result/region addition so that
// Scheme side can iterate lists and call through for each element.

#include "OperationState.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/IR/PatternMatch.h"

extern "C" {

// Create a heap-allocated OperationState for the given location and op name.
// loc_ptr:  Location opaque ptr as uptr (from mlir_ir_operation_get_loc)
// name:     registered MLIR op name string (e.g. "arith.constant")
// Returns: OperationState* as uptr — must be destroyed with
//          mlir_ir_operation_state_destroy.
uint64_t mlir_ir_operation_state_create(uint64_t loc_ptr, const char* name) {
  auto loc = mlir::Location::getFromOpaquePointer(
      reinterpret_cast<const void*>(loc_ptr));
  return reinterpret_cast<uint64_t>(new mlir::OperationState(loc, name));
}

// Add a single operand Value to the OperationState.
// state_ptr:  OperationState* as uptr
// value_ptr:  Value opaque ptr as uptr
void mlir_ir_operation_state_add_operand(uint64_t state_ptr,
                                         uint64_t value_ptr) {
  reinterpret_cast<mlir::OperationState*>(state_ptr)->addOperands(
      mlir::Value::getFromOpaquePointer(reinterpret_cast<void*>(value_ptr)));
}

// Add a single result Type to the OperationState.
// state_ptr:  OperationState* as uptr
// type_ptr:   Type opaque ptr as uptr
void mlir_ir_operation_state_add_result_type(uint64_t state_ptr,
                                             uint64_t type_ptr) {
  reinterpret_cast<mlir::OperationState*>(state_ptr)->addTypes(
      mlir::Type::getFromOpaquePointer(
          reinterpret_cast<const void*>(type_ptr)));
}

// Add one empty region to the OperationState.
// Required for ops that verify they have exactly N regions at creation time.
// state_ptr:  OperationState* as uptr
void mlir_ir_operation_state_add_region(uint64_t state_ptr) {
  reinterpret_cast<mlir::OperationState*>(state_ptr)->addRegion();
}

// Destroy an OperationState created by mlir_ir_operation_state_create.
// state_ptr:  OperationState* as uptr (no-op if 0)
void mlir_ir_operation_state_destroy(uint64_t state_ptr) {
  if (!state_ptr) {
    return;
  }
  delete reinterpret_cast<mlir::OperationState*>(state_ptr);
}

// Create an op from a prepared OperationState via a RewriterBase.
// Ownership of the OperationState is NOT transferred — caller must still
// destroy it with mlir_ir_operation_state_destroy.
// rw_ptr:     RewriterBase* as uptr
// state_ptr:  OperationState* as uptr
// Returns: Operation* as uptr, or 0 on bad input.
uint64_t mlir_ir_rewriter_base_create_from_state(uint64_t rw_ptr,
                                                 uint64_t state_ptr) {
  if (!rw_ptr || !state_ptr) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      reinterpret_cast<mlir::RewriterBase*>(rw_ptr)->create(
          *reinterpret_cast<mlir::OperationState*>(state_ptr)));
}

// Create an op from a prepared OperationState via a plain OpBuilder.
// Ownership of the OperationState is NOT transferred — caller must still
// destroy it with mlir_ir_operation_state_destroy.
// builder_ptr: OpBuilder* as uptr
// state_ptr:   OperationState* as uptr
// Returns: Operation* as uptr, or 0 on bad input.
uint64_t mlir_ir_op_builder_create_from_state(uint64_t builder_ptr,
                                              uint64_t state_ptr) {
  if (!builder_ptr || !state_ptr) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      reinterpret_cast<mlir::OpBuilder*>(builder_ptr)
          ->create(*reinterpret_cast<mlir::OperationState*>(state_ptr)));
}

} // extern "C"

namespace crest {

void registerIROperationStateBindings() {
  Sregister_symbol("mlir_ir_operation_state_create",
                   (void*)::mlir_ir_operation_state_create);
  Sregister_symbol("mlir_ir_operation_state_add_operand",
                   (void*)::mlir_ir_operation_state_add_operand);
  Sregister_symbol("mlir_ir_operation_state_add_result_type",
                   (void*)::mlir_ir_operation_state_add_result_type);
  Sregister_symbol("mlir_ir_operation_state_add_region",
                   (void*)::mlir_ir_operation_state_add_region);
  Sregister_symbol("mlir_ir_operation_state_destroy",
                   (void*)::mlir_ir_operation_state_destroy);
  Sregister_symbol("mlir_ir_rewriter_base_create_from_state",
                   (void*)::mlir_ir_rewriter_base_create_from_state);
  Sregister_symbol("mlir_ir_op_builder_create_from_state",
                   (void*)::mlir_ir_op_builder_create_from_state);
}

} // namespace crest

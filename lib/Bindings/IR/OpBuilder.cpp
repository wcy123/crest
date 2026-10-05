/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Builders.h — OpBuilder bindings.

#include "OpBuilder.h"
#include "../Support/Logging.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"

extern "C" {

// mlir::OpBuilder::create(OperationState) — op builder variant (no rewriter).
uint64_t mlir_ir_op_builder_create(uint64_t builder_ptr, uint64_t loc_op_ptr,
                                   const char* op_name, ptr operands_list,
                                   ptr result_types_list) {
  if (!builder_ptr || !loc_op_ptr) {
    return 0;
  }
  auto* builder = reinterpret_cast<mlir::OpBuilder*>(builder_ptr);
  auto* loc_op = reinterpret_cast<mlir::Operation*>(loc_op_ptr);
  llvm::SmallVector<mlir::Value> operands;
  llvm::SmallVector<mlir::Type> resultTypes;
  for (ptr cur = static_cast<ptr>(operands_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      mlir_support_logging_error("mlir_ir_op_builder_create: bad operands");
      return 0;
    }
    operands.push_back(mlir::Value::getFromOpaquePointer(
        reinterpret_cast<void*>(Sunsigned64_value(Scar(cur)))));
  }
  for (ptr cur = static_cast<ptr>(result_types_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      mlir_support_logging_error("mlir_ir_op_builder_create: bad result types");
      return 0;
    }
    resultTypes.push_back(mlir::Type::getFromOpaquePointer(
        reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))));
  }
  mlir::OperationState state(loc_op->getLoc(), op_name);
  state.addOperands(operands);
  state.addTypes(resultTypes);
  return reinterpret_cast<uint64_t>(builder->create(state));
}

// Like mlir_ir_op_builder_create but pre-allocates num_regions empty regions.
uint64_t mlir_ir_op_builder_create_with_regions(
    uint64_t builder_ptr, uint64_t loc_op_ptr, const char* op_name,
    ptr operands_list, ptr result_types_list, int num_regions) {
  if (!builder_ptr || !loc_op_ptr) {
    return 0;
  }
  auto* builder = reinterpret_cast<mlir::OpBuilder*>(builder_ptr);
  auto* loc_op = reinterpret_cast<mlir::Operation*>(loc_op_ptr);
  llvm::SmallVector<mlir::Value> operands;
  llvm::SmallVector<mlir::Type> resultTypes;
  for (ptr cur = static_cast<ptr>(operands_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      return 0;
    }
    operands.push_back(mlir::Value::getFromOpaquePointer(
        reinterpret_cast<void*>(Sunsigned64_value(Scar(cur)))));
  }
  for (ptr cur = static_cast<ptr>(result_types_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      return 0;
    }
    resultTypes.push_back(mlir::Type::getFromOpaquePointer(
        reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))));
  }
  mlir::OperationState state(loc_op->getLoc(), op_name);
  state.addOperands(operands);
  state.addTypes(resultTypes);
  for (int i = 0; i < num_regions; ++i) {
    state.addRegion();
  }
  return reinterpret_cast<uint64_t>(builder->create(state));
}

// Heap-allocate an OpBuilder positioned at the end of a block.
uint64_t mlir_ir_op_builder_at_block_end(uint64_t block_ptr) {
  if (!block_ptr) {
    return 0;
  }
  auto* block = reinterpret_cast<mlir::Block*>(block_ptr);
  return reinterpret_cast<uint64_t>(new mlir::OpBuilder(block, block->end()));
}

// Destroy an OpBuilder created by mlir_ir_op_builder_at_block_end.
void mlir_ir_op_builder_destroy(uint64_t builder_ptr) {
  if (!builder_ptr) {
    return;
  }
  delete reinterpret_cast<mlir::OpBuilder*>(builder_ptr);
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

void registerIROpBuilderBindings() {
  Sregister_symbol("mlir_ir_op_builder_create",
                   (void*)::mlir_ir_op_builder_create);
  Sregister_symbol("mlir_ir_op_builder_create_with_regions",
                   (void*)::mlir_ir_op_builder_create_with_regions);
  Sregister_symbol("mlir_ir_op_builder_at_block_end",
                   (void*)::mlir_ir_op_builder_at_block_end);
  Sregister_symbol("mlir_ir_op_builder_destroy",
                   (void*)::mlir_ir_op_builder_destroy);
  Sregister_symbol("mlir_ir_op_builder_create_from_state",
                   (void*)::mlir_ir_op_builder_create_from_state);
}

} // namespace crest

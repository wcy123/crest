/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/PatternMatch.h — RewriterBase bindings.

#include "RewriterBase.h"
#include "../Support/Logging.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/PatternMatch.h"

extern "C" {

// mlir::RewriterBase::create(OperationState) — set insertion point before
// loc_op and create the op there.
uint64_t mlir_ir_rewriter_base_create(uint64_t rewriter_ptr,
                                      uint64_t loc_op_ptr, const char* op_name,
                                      ptr operands_list,
                                      ptr result_types_list) {
  if (!rewriter_ptr || !loc_op_ptr) {
    return 0;
  }
  auto* rewriter = reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr);
  auto* loc_op = reinterpret_cast<mlir::Operation*>(loc_op_ptr);
  llvm::SmallVector<mlir::Value> operands;
  llvm::SmallVector<mlir::Type> resultTypes;
  for (ptr cur = static_cast<ptr>(operands_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      mlir_support_logging_error(
          "mlir_ir_rewriter_base_create: bad operands list");
      return 0;
    }
    operands.push_back(mlir::Value::getFromOpaquePointer(
        reinterpret_cast<void*>(Sunsigned64_value(Scar(cur)))));
  }
  for (ptr cur = static_cast<ptr>(result_types_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      mlir_support_logging_error(
          "mlir_ir_rewriter_base_create: bad result types list");
      return 0;
    }
    resultTypes.push_back(mlir::Type::getFromOpaquePointer(
        reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))));
  }
  rewriter->setInsertionPoint(loc_op);
  mlir::OperationState state(loc_op->getLoc(), op_name);
  state.addOperands(operands);
  state.addTypes(resultTypes);
  return reinterpret_cast<uint64_t>(rewriter->create(state));
}

// Like mlir_ir_rewriter_base_create but pre-allocates num_regions empty
// regions.
uint64_t mlir_ir_rewriter_base_create_with_regions(
    uint64_t rewriter_ptr, uint64_t loc_op_ptr, const char* op_name,
    ptr operands_list, ptr result_types_list, int num_regions) {
  if (!rewriter_ptr || !loc_op_ptr) {
    return 0;
  }
  auto* rewriter = reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr);
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
  rewriter->setInsertionPoint(loc_op);
  mlir::OperationState state(loc_op->getLoc(), op_name);
  state.addOperands(operands);
  state.addTypes(resultTypes);
  for (int i = 0; i < num_regions; ++i) {
    state.addRegion();
  }
  return reinterpret_cast<uint64_t>(rewriter->create(state));
}

// mlir::RewriterBase::setInsertionPoint(op)
void mlir_ir_rewriter_base_set_insertion_point_before(uint64_t rewriter_ptr,
                                                      uint64_t op_ptr) {
  if (!rewriter_ptr || !op_ptr) {
    return;
  }
  reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr)
      ->setInsertionPoint(reinterpret_cast<mlir::Operation*>(op_ptr));
}

// mlir::RewriterBase::setInsertionPointToEnd(block)
void mlir_ir_rewriter_base_set_insertion_point_to_end(uint64_t rewriter_ptr,
                                                      uint64_t block_ptr) {
  if (!rewriter_ptr || !block_ptr) {
    return;
  }
  reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr)
      ->setInsertionPointToEnd(reinterpret_cast<mlir::Block*>(block_ptr));
}

// mlir::RewriterBase::createBlock(region) + add typed arguments
uint64_t mlir_ir_rewriter_base_create_block(uint64_t rewriter_ptr,
                                            uint64_t region_ptr,
                                            ptr arg_types_list) {
  if (!rewriter_ptr || !region_ptr) {
    return 0;
  }
  auto* rewriter = reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr);
  auto* region = reinterpret_cast<mlir::Region*>(region_ptr);
  mlir::Location loc = region->getParentOp()->getLoc();
  mlir::Block* block = rewriter->createBlock(region);
  for (ptr cur = static_cast<ptr>(arg_types_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      break;
    }
    block->addArgument(
        mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))),
        loc);
  }
  rewriter->setInsertionPointToEnd(block);
  return reinterpret_cast<uint64_t>(block);
}

// mlir::RewriterBase::replaceOp
int mlir_ir_rewriter_base_replace_op(uint64_t rewriter_ptr, uint64_t old_op_ptr,
                                     uint64_t new_value_ptr) {
  if (!rewriter_ptr) {
    return 0;
  }
  reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr)
      ->replaceOp(reinterpret_cast<mlir::Operation*>(old_op_ptr),
                  mlir::Value::getFromOpaquePointer(
                      reinterpret_cast<void*>(new_value_ptr)));
  return 1;
}

// mlir::RewriterBase::eraseOp
int mlir_ir_rewriter_base_erase_op(uint64_t rewriter_ptr, uint64_t op_ptr) {
  if (!rewriter_ptr) {
    return 0;
  }
  reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr)
      ->eraseOp(reinterpret_cast<mlir::Operation*>(op_ptr));
  return 1;
}

// Clone op with new operands/types, copying attributes.
uint64_t mlir_ir_rewriter_base_clone_with_types(uint64_t rw_ptr,
                                                uint64_t op_ptr,
                                                ptr operands_list,
                                                ptr result_types_list) {
  if (!rw_ptr || !op_ptr) {
    return 0;
  }
  auto* rw = reinterpret_cast<mlir::RewriterBase*>(rw_ptr);
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  llvm::SmallVector<mlir::Value> operands;
  llvm::SmallVector<mlir::Type> resultTypes;
  for (ptr cur = operands_list; cur != Snil; cur = Scdr(cur)) {
    operands.push_back(mlir::Value::getFromOpaquePointer(
        reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))));
  }
  for (ptr cur = result_types_list; cur != Snil; cur = Scdr(cur)) {
    resultTypes.push_back(mlir::Type::getFromOpaquePointer(
        reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))));
  }
  mlir::OperationState state(op->getLoc(), op->getName());
  state.addOperands(operands);
  state.addTypes(resultTypes);
  state.addAttributes(op->getAttrs());
  return reinterpret_cast<uint64_t>(rw->create(state));
}

} // extern "C"

namespace crest {

void registerIRRewriterBaseBindings() {
  Sregister_symbol("mlir_ir_rewriter_base_create",
                   (void*)::mlir_ir_rewriter_base_create);
  Sregister_symbol("mlir_ir_rewriter_base_create_with_regions",
                   (void*)::mlir_ir_rewriter_base_create_with_regions);
  Sregister_symbol("mlir_ir_rewriter_base_set_insertion_point_before",
                   (void*)::mlir_ir_rewriter_base_set_insertion_point_before);
  Sregister_symbol("mlir_ir_rewriter_base_set_insertion_point_to_end",
                   (void*)::mlir_ir_rewriter_base_set_insertion_point_to_end);
  Sregister_symbol("mlir_ir_rewriter_base_create_block",
                   (void*)::mlir_ir_rewriter_base_create_block);
  Sregister_symbol("mlir_ir_rewriter_base_replace_op",
                   (void*)::mlir_ir_rewriter_base_replace_op);
  Sregister_symbol("mlir_ir_rewriter_base_erase_op",
                   (void*)::mlir_ir_rewriter_base_erase_op);
  Sregister_symbol("mlir_ir_rewriter_base_clone_with_types",
                   (void*)::mlir_ir_rewriter_base_clone_with_types);
}

} // namespace crest

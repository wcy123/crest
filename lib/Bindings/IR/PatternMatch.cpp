/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/PatternMatch.h — RewriterBase and RewritePatternSet bindings.

#include "PatternMatch.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/IR/PatternMatch.h"

// mlir::RewritePatternSet::RewritePatternSet(ctx) — heap-allocate a pattern
// set.
static uint64_t
mlir_ir_pattern_match_rewrite_pattern_set_create(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir::RewritePatternSet::RewritePatternSet",
                 "ctx must not be null");
    return 0; // unreachable
  }
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(new mlir::RewritePatternSet(ctx));
}

// mlir::RewritePatternSet::~RewritePatternSet — free a heap-allocated pattern
// set.
static void
mlir_ir_pattern_match_rewrite_pattern_set_destroy(uint64_t patterns_ptr) {
  if (!patterns_ptr) {
    return;
  }
  delete reinterpret_cast<mlir::RewritePatternSet*>(patterns_ptr);
}

extern "C" {

// mlir::RewriterBase::create(OperationState) — set insertion point before
// loc_op and create the op there.
static uint64_t mlir_ir_rewriter_base_create(uint64_t rewriter_ptr,
                                             uint64_t loc_op_ptr,
                                             const char* op_name,
                                             ptr operands_list,
                                             ptr result_types_list) {
  if (!rewriter_ptr) {
    scheme_error("mlir-ir-rewriter-base-create", "null rewriter pointer");
    return 0; // unreachable — error performs non-local exit
  }
  if (!loc_op_ptr) {
    scheme_error("mlir-ir-rewriter-base-create", "null loc_op pointer");
    return 0; // unreachable — error performs non-local exit
  }
  auto* rewriter = reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr);
  auto* loc_op = reinterpret_cast<mlir::Operation*>(loc_op_ptr);
  llvm::SmallVector<mlir::Value> operands;
  llvm::SmallVector<mlir::Type> resultTypes;
  for (ptr cur = static_cast<ptr>(operands_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      scheme_error("mlir-ir-rewriter-base-create", "malformed operands list");
      return 0; // unreachable — error performs non-local exit
    }
    operands.push_back(mlir::Value::getFromOpaquePointer(
        reinterpret_cast<void*>(Sunsigned64_value(Scar(cur)))));
  }
  for (ptr cur = static_cast<ptr>(result_types_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      scheme_error("mlir-ir-rewriter-base-create",
                   "malformed result types list");
      return 0; // unreachable — error performs non-local exit
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
static uint64_t mlir_ir_rewriter_base_create_with_regions(
    uint64_t rewriter_ptr, uint64_t loc_op_ptr, const char* op_name,
    ptr operands_list, ptr result_types_list, int num_regions) {
  if (!rewriter_ptr) {
    scheme_error("mlir-ir-rewriter-base-create-with-regions",
                 "null rewriter pointer");
    return 0; // unreachable — error performs non-local exit
  }
  if (!loc_op_ptr) {
    scheme_error("mlir-ir-rewriter-base-create-with-regions",
                 "null loc_op pointer");
    return 0; // unreachable — error performs non-local exit
  }
  auto* rewriter = reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr);
  auto* loc_op = reinterpret_cast<mlir::Operation*>(loc_op_ptr);
  llvm::SmallVector<mlir::Value> operands;
  llvm::SmallVector<mlir::Type> resultTypes;
  for (ptr cur = static_cast<ptr>(operands_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      scheme_error("mlir-ir-rewriter-base-create-with-regions",
                   "malformed operands list");
      return 0; // unreachable — error performs non-local exit
    }
    operands.push_back(mlir::Value::getFromOpaquePointer(
        reinterpret_cast<void*>(Sunsigned64_value(Scar(cur)))));
  }
  for (ptr cur = static_cast<ptr>(result_types_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      scheme_error("mlir-ir-rewriter-base-create-with-regions",
                   "malformed result types list");
      return 0; // unreachable — error performs non-local exit
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
static void mlir_ir_rewriter_base_set_insertion_point(uint64_t rewriter_ptr,
                                                      uint64_t op_ptr) {
  if (!rewriter_ptr) {
    scheme_error("mlir-ir-rewriter-base-set-insertion-point",
                 "null rewriter pointer");
    return; // unreachable — error performs non-local exit
  }
  if (!op_ptr) {
    scheme_error("mlir-ir-rewriter-base-set-insertion-point",
                 "null op pointer");
    return; // unreachable — error performs non-local exit
  }
  reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr)
      ->setInsertionPoint(reinterpret_cast<mlir::Operation*>(op_ptr));
}

// mlir::RewriterBase::setInsertionPointToEnd(block)
static void
mlir_ir_rewriter_base_set_insertion_point_to_end(uint64_t rewriter_ptr,
                                                 uint64_t block_ptr) {
  if (!rewriter_ptr) {
    scheme_error("mlir-ir-rewriter-base-set-insertion-point-to-end",
                 "null rewriter pointer");
    return; // unreachable — error performs non-local exit
  }
  if (!block_ptr) {
    scheme_error("mlir-ir-rewriter-base-set-insertion-point-to-end",
                 "null block pointer");
    return; // unreachable — error performs non-local exit
  }
  reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr)
      ->setInsertionPointToEnd(reinterpret_cast<mlir::Block*>(block_ptr));
}

// mlir::RewriterBase::createBlock(region) + add typed arguments
static uint64_t mlir_ir_rewriter_base_create_block(uint64_t rewriter_ptr,
                                                   uint64_t region_ptr,
                                                   ptr arg_types_list) {
  if (!rewriter_ptr) {
    scheme_error("mlir-ir-rewriter-base-create-block", "null rewriter pointer");
    return 0; // unreachable — error performs non-local exit
  }
  if (!region_ptr) {
    scheme_error("mlir-ir-rewriter-base-create-block", "null region pointer");
    return 0; // unreachable — error performs non-local exit
  }
  auto* rewriter = reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr);
  auto* region = reinterpret_cast<mlir::Region*>(region_ptr);
  mlir::Location loc = region->getParentOp()->getLoc();
  mlir::Block* block = rewriter->createBlock(region);
  for (ptr cur = static_cast<ptr>(arg_types_list); cur != Snil;
       cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      scheme_error("mlir-ir-rewriter-base-create-block",
                   "malformed arg types list");
      return 0; // unreachable — error performs non-local exit
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
static int mlir_ir_rewriter_base_replace_op(uint64_t rewriter_ptr,
                                            uint64_t old_op_ptr,
                                            uint64_t new_value_ptr) {
  if (!rewriter_ptr) {
    scheme_error("mlir-ir-rewriter-base-replace-op", "null rewriter pointer");
    return 0; // unreachable — error performs non-local exit
  }
  reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr)
      ->replaceOp(reinterpret_cast<mlir::Operation*>(old_op_ptr),
                  mlir::Value::getFromOpaquePointer(
                      reinterpret_cast<void*>(new_value_ptr)));
  return 1;
}

// mlir::RewriterBase::eraseOp
static int mlir_ir_rewriter_base_erase_op(uint64_t rewriter_ptr,
                                          uint64_t op_ptr) {
  if (!rewriter_ptr) {
    scheme_error("mlir-ir-rewriter-base-erase-op", "null rewriter pointer");
    return 0; // unreachable — error performs non-local exit
  }
  reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr)
      ->eraseOp(reinterpret_cast<mlir::Operation*>(op_ptr));
  return 1;
}

// Clone op with new operands/types, copying attributes.
static uint64_t mlir_ir_rewriter_base_clone_with_types(uint64_t rw_ptr,
                                                       uint64_t op_ptr,
                                                       ptr operands_list,
                                                       ptr result_types_list) {
  if (!rw_ptr) {
    scheme_error("mlir-ir-rewriter-base-clone-with-types",
                 "null rewriter pointer");
    return 0; // unreachable — error performs non-local exit
  }
  if (!op_ptr) {
    scheme_error("mlir-ir-rewriter-base-clone-with-types", "null op pointer");
    return 0; // unreachable — error performs non-local exit
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

// Create an op from a prepared OperationState via a RewriterBase.
// Ownership of the OperationState is NOT transferred — caller must still
// destroy it with mlir_ir_operation_state_destroy.
// rw_ptr:     RewriterBase* as uptr
// state_ptr:  OperationState* as uptr
// Returns: Operation* as uptr, or 0 on bad input.
static uint64_t mlir_ir_rewriter_base_create_from_state(uint64_t rw_ptr,
                                                        uint64_t state_ptr) {
  if (!rw_ptr) {
    scheme_error("mlir-ir-rewriter-base-create-from-state",
                 "null rewriter pointer");
    return 0; // unreachable — error performs non-local exit
  }
  if (!state_ptr) {
    scheme_error("mlir-ir-rewriter-base-create-from-state",
                 "null state pointer");
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<uint64_t>(
      reinterpret_cast<mlir::RewriterBase*>(rw_ptr)->create(
          *reinterpret_cast<mlir::OperationState*>(state_ptr)));
}

} // extern "C"

namespace crest {

void registerIRRewriterBaseBindings() {
  Sregister_symbol("mlir_ir_rewriter_base_create",
                   (void*)::mlir_ir_rewriter_base_create);
  Sregister_symbol("mlir_ir_rewriter_base_create_with_regions",
                   (void*)::mlir_ir_rewriter_base_create_with_regions);
  // Canonical name (matching C++ setInsertionPoint(op))
  Sregister_symbol("mlir_ir_rewriter_base_set_insertion_point",
                   (void*)::mlir_ir_rewriter_base_set_insertion_point);
  // Backward-compat alias
  Sregister_symbol("mlir_ir_rewriter_base_set_insertion_point_before",
                   (void*)::mlir_ir_rewriter_base_set_insertion_point);
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
  Sregister_symbol("mlir_ir_rewriter_base_create_from_state",
                   (void*)::mlir_ir_rewriter_base_create_from_state);
  Sregister_symbol("mlir::RewritePatternSet::RewritePatternSet",
                   (void*)::mlir_ir_pattern_match_rewrite_pattern_set_create);
  Sregister_symbol("mlir::RewritePatternSet::~RewritePatternSet",
                   (void*)::mlir_ir_pattern_match_rewrite_pattern_set_destroy);
}

} // namespace crest

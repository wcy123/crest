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

// mlir::RewriterBase::setInsertionPoint(op)
static void mlir_ir_rewriter_base_set_insertion_point(uint64_t rewriter_ptr,
                                                      uint64_t op_ptr) {
  if (!rewriter_ptr) {
    scheme_error("mlir-ir-rewriter-base-set-insertion-point",
                 "null rewriter pointer");
  }
  if (!op_ptr) {
    scheme_error("mlir-ir-rewriter-base-set-insertion-point",
                 "null op pointer");
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
  }
  if (!block_ptr) {
    scheme_error("mlir-ir-rewriter-base-set-insertion-point-to-end",
                 "null block pointer");
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
  }
  if (!region_ptr) {
    scheme_error("mlir-ir-rewriter-base-create-block", "null region pointer");
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
  }
  reinterpret_cast<mlir::RewriterBase*>(rewriter_ptr)
      ->eraseOp(reinterpret_cast<mlir::Operation*>(op_ptr));
  return 1;
}

// RewriterBase IS-A OpBuilder (single inheritance). Casting RewriterBase* to
// OpBuilder* is safe — the base subobject is at offset 0, and listener
// notifications fire correctly since RewriterBase registers itself as the
// OpBuilder listener. This wrapper keeps the canonical symbol name so that
// any cached Scheme code still resolves correctly.
static uint64_t mlir_ir_rewriter_base_create_from_state(uint64_t rw_ptr,
                                                        uint64_t state_ptr) {
  if (!rw_ptr) {
    scheme_error("mlir::RewriterBase::create<OperationState>", "null rewriter");
  }
  if (!state_ptr) {
    scheme_error("mlir::RewriterBase::create<OperationState>", "null state");
  }
  return reinterpret_cast<uint64_t>(
      reinterpret_cast<mlir::RewriterBase*>(rw_ptr)->create(
          *reinterpret_cast<mlir::OperationState*>(state_ptr)));
}

} // extern "C"

namespace crest {

void registerIRRewriterBaseBindings() {
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

  Sregister_symbol("mlir::RewriterBase::create<OperationState>",
                   (void*)::mlir_ir_rewriter_base_create_from_state);
  Sregister_symbol("mlir::RewritePatternSet::RewritePatternSet",
                   (void*)::mlir_ir_pattern_match_rewrite_pattern_set_create);
  Sregister_symbol("mlir::RewritePatternSet::~RewritePatternSet",
                   (void*)::mlir_ir_pattern_match_rewrite_pattern_set_destroy);
}

} // namespace crest

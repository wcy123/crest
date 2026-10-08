/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/PatternMatch.h — RewriterBase and RewritePatternSet bindings.

#include "PatternMatch.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

void registerIRRewriterBaseBindings() {
  Sregister_symbol(
      "mlir_ir_rewriter_base_set_insertion_point",
      (void*)+[](uint64_t rewriter_ptr, uint64_t op_ptr) -> void {
        if (!op_ptr) {
          scheme_error("mlir_ir_rewriter_base_set_insertion_point",
                       "null op pointer");
        }
        crest_ref<mlir::RewriterBase>(
            rewriter_ptr, "mlir_ir_rewriter_base_set_insertion_point")
            ->setInsertionPoint(reinterpret_cast<mlir::Operation*>(op_ptr));
      });
  // Backward-compat alias
  Sregister_symbol(
      "mlir_ir_rewriter_base_set_insertion_point_before",
      (void*)+[](uint64_t rewriter_ptr, uint64_t op_ptr) -> void {
        if (!op_ptr) {
          scheme_error("mlir_ir_rewriter_base_set_insertion_point_before",
                       "null op pointer");
        }
        crest_ref<mlir::RewriterBase>(
            rewriter_ptr, "mlir_ir_rewriter_base_set_insertion_point_before")
            ->setInsertionPoint(reinterpret_cast<mlir::Operation*>(op_ptr));
      });
  Sregister_symbol(
      "mlir_ir_rewriter_base_set_insertion_point_to_end",
      (void*)+[](uint64_t rewriter_ptr, uint64_t block_ptr) -> void {
        if (!block_ptr) {
          scheme_error("mlir_ir_rewriter_base_set_insertion_point_to_end",
                       "null block pointer");
        }
        crest_ref<mlir::RewriterBase>(
            rewriter_ptr, "mlir_ir_rewriter_base_set_insertion_point_to_end")
            ->setInsertionPointToEnd(reinterpret_cast<mlir::Block*>(block_ptr));
      });
  Sregister_symbol(
      "mlir_ir_rewriter_base_create_block",
      (void*)+[](uint64_t rewriter_ptr, uint64_t region_ptr,
                 ptr arg_types_list) -> uint64_t {
        if (!region_ptr) {
          scheme_error("mlir_ir_rewriter_base_create_block",
                       "null region pointer");
        }
        auto* rewriter = crest_ref<mlir::RewriterBase>(
            rewriter_ptr, "mlir_ir_rewriter_base_create_block");
        auto* region = reinterpret_cast<mlir::Region*>(region_ptr);
        mlir::Location loc = region->getParentOp()->getLoc();
        mlir::Block* block = rewriter->createBlock(region);
        for (ptr cur = static_cast<ptr>(arg_types_list); cur != Snil;
             cur = Scdr(cur)) {
          if (!Spairp(cur)) {
            scheme_error("mlir_ir_rewriter_base_create_block",
                         "malformed arg types list");
          }
          block->addArgument(
              mlir::Type::getFromOpaquePointer(
                  reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))),
              loc);
        }
        rewriter->setInsertionPointToEnd(block);
        return reinterpret_cast<uint64_t>(block);
      });
  Sregister_symbol(
      "mlir_ir_rewriter_base_replace_op",
      (void*)+[](uint64_t rewriter_ptr, uint64_t old_op_ptr,
                 uint64_t new_value_ptr) -> int {
        crest_ref<mlir::RewriterBase>(rewriter_ptr,
                                      "mlir_ir_rewriter_base_replace_op")
            ->replaceOp(reinterpret_cast<mlir::Operation*>(old_op_ptr),
                        mlir::Value::getFromOpaquePointer(
                            reinterpret_cast<void*>(new_value_ptr)));
        return 1;
      });
  Sregister_symbol(
      "mlir_ir_rewriter_base_erase_op",
      (void*)+[](uint64_t rewriter_ptr, uint64_t op_ptr) -> int {
        crest_ref<mlir::RewriterBase>(rewriter_ptr,
                                      "mlir_ir_rewriter_base_erase_op")
            ->eraseOp(reinterpret_cast<mlir::Operation*>(op_ptr));
        return 1;
      });
  // RewriterBase IS-A OpBuilder (single inheritance).
  // CrestRef<RewriterBase>->ptr gives the raw RewriterBase* which can be safely
  // used with RewriterBase::create.
  Sregister_symbol(
      "mlir::RewriterBase::create<OperationState>",
      (void*)+[](uint64_t rw_ptr, uint64_t state_ptr) -> uint64_t {
        auto* rw = crest_ref<mlir::RewriterBase>(
            rw_ptr, "mlir::RewriterBase::create<OperationState>");
        auto& state = crest_owned<mlir::OperationState>(
            state_ptr, "mlir::RewriterBase::create<OperationState>");
        return reinterpret_cast<uint64_t>(rw->create(state));
      });
  Sregister_symbol(
      "mlir::RewritePatternSet::RewritePatternSet",
      (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::RewritePatternSet::RewritePatternSet",
                       "ctx must not be null");
        }
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        return reinterpret_cast<uint64_t>(
            new CrestOwned<mlir::RewritePatternSet>(ctx));
      });
  Sregister_symbol(
      "crest::isa<CrestOwned<mlir::RewritePatternSet>>",
      (void*)+[](uint64_t ptr) -> int {
        if (!ptr) {
          return 0;
        }
        return reinterpret_cast<CrestObject*>(ptr)
                       ->isa<CrestOwned<mlir::RewritePatternSet>>()
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "crest::isa<CrestRef<mlir::RewriterBase>>",
      (void*)+[](uint64_t ptr) -> int {
        if (!ptr) {
          return 0;
        }
        return reinterpret_cast<CrestObject*>(ptr)
                       ->isa<CrestRef<mlir::RewriterBase>>()
                   ? 1
                   : 0;
      });
}

} // namespace crest

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
      "mlir::RewriterBase::setInsertionPoint",
      (void*)+[](uint64_t rewriter_ptr, uint64_t op_ptr) -> void {
        if (!op_ptr) {
          scheme_error("mlir::RewriterBase::setInsertionPoint",
                       "null op pointer");
        }
        crest::as_ptr<mlir::RewriterBase>(
            rewriter_ptr, "mlir::RewriterBase::setInsertionPoint")
            ->setInsertionPoint(reinterpret_cast<mlir::Operation*>(op_ptr));
      });
  Sregister_symbol(
      "mlir::RewriterBase::setInsertionPointToEnd",
      (void*)+[](uint64_t rewriter_ptr, uint64_t block_ptr) -> void {
        if (!block_ptr) {
          scheme_error("mlir::RewriterBase::setInsertionPointToEnd",
                       "null block pointer");
        }
        crest::as_ptr<mlir::RewriterBase>(
            rewriter_ptr, "mlir::RewriterBase::setInsertionPointToEnd")
            ->setInsertionPointToEnd(reinterpret_cast<mlir::Block*>(block_ptr));
      });
  Sregister_symbol(
      "mlir::RewriterBase::createBlock",
      (void*)+[](uint64_t rewriter_ptr, uint64_t region_ptr,
                 ptr arg_types_list) -> uint64_t {
        if (!region_ptr) {
          scheme_error("mlir::RewriterBase::createBlock",
                       "null region pointer");
        }
        auto* rewriter = crest::as_ptr<mlir::RewriterBase>(
            rewriter_ptr, "mlir::RewriterBase::createBlock");
        auto* region = reinterpret_cast<mlir::Region*>(region_ptr);
        mlir::Operation* parent = region->getParentOp();
        mlir::Location loc =
            parent ? parent->getLoc()
                   : mlir::UnknownLoc::get(rewriter->getContext());
        mlir::Block* block = rewriter->createBlock(region);
        for (ptr cur = static_cast<ptr>(arg_types_list); cur != Snil;
             cur = Scdr(cur)) {
          if (!Spairp(cur)) {
            scheme_error("mlir::RewriterBase::createBlock",
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
      "mlir::RewriterBase::replaceOp",
      (void*)+[](uint64_t rewriter_ptr, uint64_t old_op_ptr,
                 uint64_t new_value_ptr) -> int {
        if (!old_op_ptr) {
          scheme_error("mlir::RewriterBase::replaceOp", "null op pointer");
        }
        crest::as_ptr<mlir::RewriterBase>(rewriter_ptr,
                                          "mlir::RewriterBase::replaceOp")
            ->replaceOp(reinterpret_cast<mlir::Operation*>(old_op_ptr),
                        mlir::Value::getFromOpaquePointer(
                            reinterpret_cast<void*>(new_value_ptr)));
        return 1;
      });
  Sregister_symbol(
      "mlir::RewriterBase::eraseOp",
      (void*)+[](uint64_t rewriter_ptr, uint64_t op_ptr) -> int {
        crest::as_ptr<mlir::RewriterBase>(rewriter_ptr,
                                          "mlir::RewriterBase::eraseOp")
            ->eraseOp(reinterpret_cast<mlir::Operation*>(op_ptr));
        return 1;
      });
  // RewriterBase IS-A OpBuilder (single inheritance).
  // CrestRef<RewriterBase>->ptr gives the raw RewriterBase* which can be safely
  // used with RewriterBase::create.
  Sregister_symbol(
      "mlir::RewriterBase::create<OperationState>",
      (void*)+[](uint64_t rw_ptr, uint64_t state_ptr) -> uint64_t {
        auto* rw = crest::as_ptr<mlir::RewriterBase>(
            rw_ptr, "mlir::RewriterBase::create<OperationState>");
        auto& state = crest::as_ref<mlir::OperationState>(
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
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__);
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

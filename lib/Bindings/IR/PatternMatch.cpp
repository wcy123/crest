/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/PatternMatch.h — RewriterBase and RewritePatternSet bindings.

#include "PatternMatch.h"
#include "../Support/CrestObject.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/IR/Region.h"

namespace crest {

void registerIRRewriterBaseBindings() {
  register_binding(
      "mlir::RewriterBase::setInsertionPoint",
      [](uint64_t rewriter_ptr, uint64_t op_ptr) -> llvm::Error {
        if (!op_ptr) {
          return fail("mlir::RewriterBase::setInsertionPoint",
                      llvm::Twine("null op pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::CrestBox<mlir::RewriterBase*>::inner(
                      rewriter_ptr, "mlir::RewriterBase::setInsertionPoint"));

        crest_lookup1.setInsertionPoint(
            reinterpret_cast<mlir::Operation*>(op_ptr));
        return llvm::Error::success();
      });
  register_binding(
      "mlir::RewriterBase::setInsertionPointToEnd",
      [](uint64_t rewriter_ptr, uint64_t block_ptr) -> llvm::Error {
        if (!block_ptr) {
          return fail("mlir::RewriterBase::setInsertionPointToEnd",
                      llvm::Twine("null block pointer"));
        }
        CREST_TRY(
            crest_lookup1,
            crest::CrestBox<mlir::RewriterBase*>::inner(
                rewriter_ptr, "mlir::RewriterBase::setInsertionPointToEnd"));

        crest_lookup1.setInsertionPointToEnd(
            reinterpret_cast<mlir::Block*>(block_ptr));
        return llvm::Error::success();
      });
  register_binding(
      "mlir::RewriterBase::createBlock",
      [](uint64_t rewriter_ptr, uint64_t region_ptr,
         ptr arg_types_list) -> llvm::Expected<uint64_t> {
        if (!region_ptr) {
          return fail("mlir::RewriterBase::createBlock",
                      llvm::Twine("null region pointer"));
        }
        CREST_TRY(rewriter,
                  crest::CrestBox<mlir::RewriterBase*>::inner(
                      rewriter_ptr, "mlir::RewriterBase::createBlock"));
        auto* region = reinterpret_cast<mlir::Region*>(region_ptr);
        mlir::Operation* parent = region->getParentOp();
        mlir::Location loc = parent
                                 ? parent->getLoc()
                                 : mlir::UnknownLoc::get(rewriter.getContext());
        mlir::Block* block = rewriter.createBlock(region);
        for (ptr cur = static_cast<ptr>(arg_types_list); cur != Snil;
             cur = Scdr(cur)) {
          if (!Spairp(cur)) {
            return fail("mlir::RewriterBase::createBlock",
                        llvm::Twine("malformed arg types list"));
          }
          block->addArgument(
              mlir::Type::getFromOpaquePointer(
                  reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))),
              loc);
        }
        rewriter.setInsertionPointToEnd(block);
        return reinterpret_cast<uint64_t>(block);
      });
  register_binding(
      "mlir::RewriterBase::replaceOp",
      [](uint64_t rewriter_ptr, uint64_t old_op_ptr,
         uint64_t new_value_ptr) -> llvm::Expected<int> {
        if (!old_op_ptr) {
          return fail("mlir::RewriterBase::replaceOp",
                      llvm::Twine("null op pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::CrestBox<mlir::RewriterBase*>::inner(
                      rewriter_ptr, "mlir::RewriterBase::replaceOp"));

        crest_lookup1.replaceOp(reinterpret_cast<mlir::Operation*>(old_op_ptr),
                                mlir::Value::getFromOpaquePointer(
                                    reinterpret_cast<void*>(new_value_ptr)));
        return 1;
      });
  register_binding(
      "mlir::RewriterBase::eraseOp",
      [](uint64_t rewriter_ptr, uint64_t op_ptr) -> llvm::Expected<int> {
        CREST_TRY(crest_lookup1,
                  crest::CrestBox<mlir::RewriterBase*>::inner(
                      rewriter_ptr, "mlir::RewriterBase::eraseOp"));

        crest_lookup1.eraseOp(reinterpret_cast<mlir::Operation*>(op_ptr));
        return 1;
      });
  // RewriterBase IS-A OpBuilder (single inheritance). The shell's inner() is
  // the RewriterBase itself, which can be safely used with
  // RewriterBase::create.
  register_binding(
      "mlir::RewriterBase::create<OperationState>",
      [](uint64_t rw_ptr, uint64_t state_ptr) -> llvm::Expected<uint64_t> {
        CREST_TRY(rw,
                  crest::CrestBox<mlir::RewriterBase*>::inner(
                      rw_ptr, "mlir::RewriterBase::create<OperationState>"));
        CREST_TRY(state,
                  crest::CrestBox<mlir::OperationState>::inner(
                      state_ptr, "mlir::RewriterBase::create<OperationState>"));
        return reinterpret_cast<uint64_t>(rw.create(state));
      });
  // inlineRegionBefore: move all blocks of the source region to the front of
  // the destination region. Rewriter-only: the shell must be a
  // CrestBox<RewriterBase*>, so the call reaches the real rewriter (the
  // conversion rewriter overrides several RewriterBase methods).
  // (rw-ptr src-region-ptr dest-region-ptr) -> void
  register_binding(
      "mlir::RewriterBase::inlineRegionBefore",
      [](uint64_t rw_ptr, uint64_t src_ptr, uint64_t dest_ptr) -> llvm::Error {
        CREST_TRY(rw, crest::CrestBox<mlir::RewriterBase*>::inner(
                          rw_ptr, "mlir::RewriterBase::inlineRegionBefore"));
        auto* src = reinterpret_cast<mlir::Region*>(src_ptr);
        auto* dest = reinterpret_cast<mlir::Region*>(dest_ptr);
        rw.inlineRegionBefore(*src, *dest, dest->begin());
        return llvm::Error::success();
      });
  register_binding("crest::isa<CrestBox<mlir::RewriterBase*>>",
                   [](uint64_t ptr) -> int {
                     if (!ptr) {
                       return 0;
                     }
                     return reinterpret_cast<CrestObject*>(ptr)
                                    ->isa<CrestBox<mlir::RewriterBase*>>()
                                ? 1
                                : 0;
                   });
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-RewritePatternSet, which frees it after its body; a box that is never
  // freed leaks.
  register_binding(
      "mlir::RewritePatternSet::RewritePatternSet",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::RewritePatternSet::RewritePatternSet",
                      llvm::Twine("ctx must not be null"));
        }
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            new CrestBox<mlir::RewritePatternSet>(ctx));
      });
  register_binding("crest::isa<CrestBox<mlir::RewritePatternSet>>",
                   [](uint64_t ptr) -> int {
                     if (!ptr) {
                       return 0;
                     }
                     return reinterpret_cast<CrestObject*>(ptr)
                                    ->isa<CrestBox<mlir::RewritePatternSet>>()
                                ? 1
                                : 0;
                   });

  // mlir::RewriterBase::setInsertionPointToStart: set insertion before first op
  // in block. (rw-ptr block-ptr) → void
  register_binding(
      "mlir::RewriterBase::setInsertionPointToStart",
      [](uint64_t rw_ptr, uint64_t block_ptr) -> llvm::Error {
        CREST_TRY(rw,
                  crest::CrestBox<mlir::RewriterBase*>::inner(
                      rw_ptr, "mlir::RewriterBase::setInsertionPointToStart"));
        rw.setInsertionPointToStart(reinterpret_cast<mlir::Block*>(block_ptr));
        return llvm::Error::success();
      });
}

} // namespace crest

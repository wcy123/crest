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
  Sregister_symbol(
      "mlir::RewriterBase::setInsertionPoint",
      (void*)+[](uint64_t rewriter_ptr, uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::RewriterBase::setInsertionPoint",
                              "null op pointer");
        }
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::RewriterBase*>::inner(rewriter_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::RewriterBase::setInsertionPoint",
              "null pointer or not a CrestBox<mlir::RewriterBase*>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.setInsertionPoint(
            reinterpret_cast<mlir::Operation*>(op_ptr));
        return Svoid;
      });
  Sregister_symbol(
      "mlir::RewriterBase::setInsertionPointToEnd",
      (void*)+[](uint64_t rewriter_ptr, uint64_t block_ptr) -> ptr {
        if (!block_ptr) {
          return scheme_error("mlir::RewriterBase::setInsertionPointToEnd",
                              "null block pointer");
        }
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::RewriterBase*>::inner(rewriter_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::RewriterBase::setInsertionPointToEnd",
              "null pointer or not a CrestBox<mlir::RewriterBase*>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.setInsertionPointToEnd(
            reinterpret_cast<mlir::Block*>(block_ptr));
        return Svoid;
      });
  Sregister_symbol(
      "mlir::RewriterBase::createBlock",
      (void*)+[](uint64_t rewriter_ptr, uint64_t region_ptr,
                 ptr arg_types_list) -> ptr {
        if (!region_ptr) {
          return scheme_error("mlir::RewriterBase::createBlock",
                              "null region pointer");
        }
        auto* rewriter_box =
            crest::CrestBox<mlir::RewriterBase*>::inner(rewriter_ptr);
        if (!rewriter_box) {
          return scheme_error(
              "mlir::RewriterBase::createBlock",
              "null pointer or not a CrestBox<mlir::RewriterBase*>");
        }
        auto& rewriter = *rewriter_box;
        auto* region = reinterpret_cast<mlir::Region*>(region_ptr);
        mlir::Operation* parent = region->getParentOp();
        mlir::Location loc = parent
                                 ? parent->getLoc()
                                 : mlir::UnknownLoc::get(rewriter.getContext());
        mlir::Block* block = rewriter.createBlock(region);
        for (ptr cur = static_cast<ptr>(arg_types_list); cur != Snil;
             cur = Scdr(cur)) {
          if (!Spairp(cur)) {
            return scheme_error("mlir::RewriterBase::createBlock",
                                "malformed arg types list");
          }
          block->addArgument(
              mlir::Type::getFromOpaquePointer(
                  reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))),
              loc);
        }
        rewriter.setInsertionPointToEnd(block);
        return Sunsigned64(reinterpret_cast<uint64_t>(block));
      });
  Sregister_symbol(
      "mlir::RewriterBase::replaceOp",
      (void*)+[](uint64_t rewriter_ptr, uint64_t old_op_ptr,
                 uint64_t new_value_ptr) -> ptr {
        if (!old_op_ptr) {
          return scheme_error("mlir::RewriterBase::replaceOp",
                              "null op pointer");
        }
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::RewriterBase*>::inner(rewriter_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::RewriterBase::replaceOp",
              "null pointer or not a CrestBox<mlir::RewriterBase*>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.replaceOp(reinterpret_cast<mlir::Operation*>(old_op_ptr),
                                mlir::Value::getFromOpaquePointer(
                                    reinterpret_cast<void*>(new_value_ptr)));
        return Sinteger64(1);
      });
  Sregister_symbol(
      "mlir::RewriterBase::eraseOp",
      (void*)+[](uint64_t rewriter_ptr, uint64_t op_ptr) -> ptr {
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::RewriterBase*>::inner(rewriter_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::RewriterBase::eraseOp",
              "null pointer or not a CrestBox<mlir::RewriterBase*>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.eraseOp(reinterpret_cast<mlir::Operation*>(op_ptr));
        return Sinteger64(1);
      });
  // RewriterBase IS-A OpBuilder (single inheritance). The shell's inner() is
  // the RewriterBase itself, which can be safely used with
  // RewriterBase::create.
  Sregister_symbol(
      "mlir::RewriterBase::create<OperationState>",
      (void*)+[](uint64_t rw_ptr, uint64_t state_ptr) -> ptr {
        auto* rw_box = crest::CrestBox<mlir::RewriterBase*>::inner(rw_ptr);
        if (!rw_box) {
          return scheme_error(
              "mlir::RewriterBase::create<OperationState>",
              "null pointer or not a CrestBox<mlir::RewriterBase*>");
        }
        auto& rw = *rw_box;
        auto* state_box =
            crest::CrestBox<mlir::OperationState>::inner(state_ptr);
        if (!state_box) {
          return scheme_error(
              "mlir::RewriterBase::create<OperationState>",
              "null pointer or not a CrestBox<mlir::OperationState>");
        }
        auto& state = *state_box;
        return Sunsigned64(reinterpret_cast<uint64_t>(rw.create(state)));
      });
  // inlineRegionBefore: move all blocks of the source region to the front of
  // the destination region. Rewriter-only: the shell must be a
  // CrestBox<RewriterBase*>, so the call reaches the real rewriter (the
  // conversion rewriter overrides several RewriterBase methods).
  // (rw-ptr src-region-ptr dest-region-ptr) -> void
  Sregister_symbol(
      "mlir::RewriterBase::inlineRegionBefore",
      (void*)+[](uint64_t rw_ptr, uint64_t src_ptr, uint64_t dest_ptr) -> ptr {
        auto* rw_box = crest::CrestBox<mlir::RewriterBase*>::inner(rw_ptr);
        if (!rw_box) {
          return scheme_error(
              "mlir::RewriterBase::inlineRegionBefore",
              "null pointer or not a CrestBox<mlir::RewriterBase*>");
        }
        auto& rw = *rw_box;
        auto* src = reinterpret_cast<mlir::Region*>(src_ptr);
        auto* dest = reinterpret_cast<mlir::Region*>(dest_ptr);
        rw.inlineRegionBefore(*src, *dest, dest->begin());
        return Svoid;
      });
  Sregister_symbol(
      "crest::isa<CrestBox<mlir::RewriterBase*>>",
      (void*)+[](uint64_t address) -> ptr {
        if (!address) {
          return Sinteger64(0);
        }
        return Sinteger64(reinterpret_cast<CrestObject*>(address)
                                  ->isa<CrestBox<mlir::RewriterBase*>>()
                              ? 1
                              : 0);
      });
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-RewritePatternSet, which frees it after its body; a box that is never
  // freed leaks.
  Sregister_symbol(
      "mlir::RewritePatternSet::RewritePatternSet",
      (void*)+[](uint64_t ctx_ptr) -> ptr {
        if (!ctx_ptr) {
          return scheme_error("mlir::RewritePatternSet::RewritePatternSet",
                              "ctx must not be null");
        }
        auto* ctx = crest::as_context(ctx_ptr);
        return Sunsigned64(reinterpret_cast<uint64_t>(
            new CrestBox<mlir::RewritePatternSet>(ctx)));
      });
  Sregister_symbol(
      "crest::isa<CrestBox<mlir::RewritePatternSet>>",
      (void*)+[](uint64_t address) -> ptr {
        if (!address) {
          return Sinteger64(0);
        }
        return Sinteger64(reinterpret_cast<CrestObject*>(address)
                                  ->isa<CrestBox<mlir::RewritePatternSet>>()
                              ? 1
                              : 0);
      });

  // mlir::RewriterBase::setInsertionPointToStart: set insertion before first op
  // in block. (rw-ptr block-ptr) → void
  Sregister_symbol(
      "mlir::RewriterBase::setInsertionPointToStart",
      (void*)+[](uint64_t rw_ptr, uint64_t block_ptr) -> ptr {
        auto* rw_box = crest::CrestBox<mlir::RewriterBase*>::inner(rw_ptr);
        if (!rw_box) {
          return scheme_error(
              "mlir::RewriterBase::setInsertionPointToStart",
              "null pointer or not a CrestBox<mlir::RewriterBase*>");
        }
        auto& rw = *rw_box;
        rw.setInsertionPointToStart(reinterpret_cast<mlir::Block*>(block_ptr));
        return Svoid;
      });
}

} // namespace crest

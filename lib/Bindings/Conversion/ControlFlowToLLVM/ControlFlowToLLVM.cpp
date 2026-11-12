/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Conversion/ControlFlowToLLVM/ControlFlowToLLVM.h

#include "ControlFlowToLLVM.h"
#include "../../Support/CrestObject.h"
#include "../../Support/Result.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Conversion/ControlFlowToLLVM/ControlFlowToLLVM.h"
#include "mlir/Conversion/LLVMCommon/TypeConverter.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

void registerConversionControlFlowToLLVMBindings() {
  // mlir::cf::populateControlFlowToLLVMConversionPatterns
  // (type-converter-ptr patterns-ptr) → void
  Sregister_symbol(
      "mlir::cf::populateControlFlowToLLVMConversionPatterns",
      (void*)+[](uint64_t tc_ptr, uint64_t patterns_ptr) -> ptr {
        auto* tc_box = crest::CrestBox<mlir::LLVMTypeConverter>::inner(tc_ptr);
        if (!tc_box) {
          return scheme_error(
              "mlir::cf::populateControlFlowToLLVMConversionPatterns",
              "null pointer or not a CrestBox<mlir::LLVMTypeConverter>");
        }
        auto& tc = *tc_box;
        auto* patterns_box =
            crest::as_ref<mlir::RewritePatternSet>(patterns_ptr);
        if (!patterns_box) {
          return scheme_error(
              "mlir::cf::populateControlFlowToLLVMConversionPatterns",
              "null pointer or not a CrestBox<mlir::RewritePatternSet> or "
              "CrestBox<mlir::RewritePatternSet*>");
        }
        auto& patterns = *patterns_box;
        mlir::cf::populateControlFlowToLLVMConversionPatterns(tc, patterns);
        return Svoid;
      });

  // mlir::cf::populateAssertToLLVMConversionPattern (Ch7 addition)
  // (type-converter-ptr patterns-ptr) → void
  Sregister_symbol(
      "mlir::cf::populateAssertToLLVMConversionPattern",
      (void*)+[](uint64_t tc_ptr, uint64_t patterns_ptr) -> ptr {
        auto* tc_box = crest::CrestBox<mlir::LLVMTypeConverter>::inner(tc_ptr);
        if (!tc_box) {
          return scheme_error(
              "mlir::cf::populateAssertToLLVMConversionPattern",
              "null pointer or not a CrestBox<mlir::LLVMTypeConverter>");
        }
        auto& tc = *tc_box;
        auto* patterns_box =
            crest::as_ref<mlir::RewritePatternSet>(patterns_ptr);
        if (!patterns_box) {
          return scheme_error(
              "mlir::cf::populateAssertToLLVMConversionPattern",
              "null pointer or not a CrestBox<mlir::RewritePatternSet> or "
              "CrestBox<mlir::RewritePatternSet*>");
        }
        auto& patterns = *patterns_box;
        mlir::cf::populateAssertToLLVMConversionPattern(tc, patterns);
        return Svoid;
      });
}

} // namespace crest

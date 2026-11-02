/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Conversion/ControlFlowToLLVM/ControlFlowToLLVM.h

#include "ControlFlowToLLVM.h"
#include "../../Support/CrestObject.h"
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
      (void*)+[](uint64_t tc_ptr, uint64_t patterns_ptr) -> void {
        auto& tc = crest::as_ref<mlir::LLVMTypeConverter>(
            tc_ptr, "mlir::cf::populateControlFlowToLLVMConversionPatterns");
        auto& patterns = crest::as_ref<mlir::RewritePatternSet>(
            patterns_ptr,
            "mlir::cf::populateControlFlowToLLVMConversionPatterns");
        mlir::cf::populateControlFlowToLLVMConversionPatterns(tc, patterns);
      });

  // mlir::cf::populateAssertToLLVMConversionPattern (Ch7 addition)
  // (type-converter-ptr patterns-ptr) → void
  Sregister_symbol(
      "mlir::cf::populateAssertToLLVMConversionPattern",
      (void*)+[](uint64_t tc_ptr, uint64_t patterns_ptr) -> void {
        auto& tc = crest::as_ref<mlir::LLVMTypeConverter>(
            tc_ptr, "mlir::cf::populateAssertToLLVMConversionPattern");
        auto& patterns = crest::as_ref<mlir::RewritePatternSet>(
            patterns_ptr, "mlir::cf::populateAssertToLLVMConversionPattern");
        mlir::cf::populateAssertToLLVMConversionPattern(tc, patterns);
      });
}

} // namespace crest

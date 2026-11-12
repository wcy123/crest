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
  register_binding(
      "mlir::cf::populateControlFlowToLLVMConversionPatterns",
      [](uint64_t tc_ptr, uint64_t patterns_ptr) -> llvm::Error {
        CREST_TRY(tc,
                  crest::CrestBox<mlir::LLVMTypeConverter>::inner(
                      tc_ptr,
                      "mlir::cf::populateControlFlowToLLVMConversionPatterns"));
        CREST_TRY(patterns,
                  crest::as_ref<mlir::RewritePatternSet>(
                      patterns_ptr,
                      "mlir::cf::populateControlFlowToLLVMConversionPatterns"));
        mlir::cf::populateControlFlowToLLVMConversionPatterns(tc, patterns);
        return llvm::Error::success();
      });

  // mlir::cf::populateAssertToLLVMConversionPattern (Ch7 addition)
  // (type-converter-ptr patterns-ptr) → void
  register_binding(
      "mlir::cf::populateAssertToLLVMConversionPattern",
      [](uint64_t tc_ptr, uint64_t patterns_ptr) -> llvm::Error {
        CREST_TRY(
            tc, crest::CrestBox<mlir::LLVMTypeConverter>::inner(
                    tc_ptr, "mlir::cf::populateAssertToLLVMConversionPattern"));
        CREST_TRY(patterns,
                  crest::as_ref<mlir::RewritePatternSet>(
                      patterns_ptr,
                      "mlir::cf::populateAssertToLLVMConversionPattern"));
        mlir::cf::populateAssertToLLVMConversionPattern(tc, patterns);
        return llvm::Error::success();
      });
}

} // namespace crest

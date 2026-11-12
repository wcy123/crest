/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Conversion/MemRefToLLVM/MemRefToLLVM.h

#include "MemRefToLLVM.h"
#include "../../Support/CrestObject.h"
#include "../../Support/Result.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Conversion/LLVMCommon/TypeConverter.h"
#include "mlir/Conversion/MemRefToLLVM/MemRefToLLVM.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

void registerConversionMemRefToLLVMBindings() {
  // mlir::populateFinalizeMemRefToLLVMConversionPatterns
  // (type-converter-ptr patterns-ptr) → void
  register_binding(
      "mlir::populateFinalizeMemRefToLLVMConversionPatterns",
      [](uint64_t tc_ptr, uint64_t patterns_ptr) -> llvm::Error {
        CREST_TRY(tc,
                  crest::CrestBox<mlir::LLVMTypeConverter>::inner(
                      tc_ptr,
                      "mlir::populateFinalizeMemRefToLLVMConversionPatterns"));
        CREST_TRY(patterns,
                  crest::as_ref<mlir::RewritePatternSet>(
                      patterns_ptr,
                      "mlir::populateFinalizeMemRefToLLVMConversionPatterns"));
        mlir::populateFinalizeMemRefToLLVMConversionPatterns(tc, patterns);
        return llvm::Error::success();
      });
}

} // namespace crest

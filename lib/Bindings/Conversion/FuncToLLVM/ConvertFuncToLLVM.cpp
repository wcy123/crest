/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Conversion/FuncToLLVM/ConvertFuncToLLVM.h

#include "ConvertFuncToLLVM.h"
#include "../../Support/CrestObject.h"
#include "../../Support/Result.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Conversion/FuncToLLVM/ConvertFuncToLLVM.h"
#include "mlir/Conversion/LLVMCommon/TypeConverter.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

void registerConversionFuncToLLVMBindings() {
  // mlir::populateFuncToLLVMConversionPatterns
  // (type-converter-ptr patterns-ptr) → void
  register_binding(
      "mlir::populateFuncToLLVMConversionPatterns",
      [](uint64_t tc_ptr, uint64_t patterns_ptr) -> llvm::Error {
        CREST_TRY(tc,
                  crest::CrestBox<mlir::LLVMTypeConverter>::tryInner(
                      tc_ptr, "mlir::populateFuncToLLVMConversionPatterns"));
        CREST_TRY(patterns, crest::try_as_ref<mlir::RewritePatternSet>(
                                patterns_ptr,
                                "mlir::populateFuncToLLVMConversionPatterns"));
        mlir::populateFuncToLLVMConversionPatterns(tc, patterns);
        return llvm::Error::success();
      });
}

} // namespace crest

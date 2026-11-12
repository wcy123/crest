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
  Sregister_symbol(
      "mlir::populateFuncToLLVMConversionPatterns",
      (void*)+[](uint64_t tc_ptr, uint64_t patterns_ptr) -> ptr {
        auto* tc_box = crest::CrestBox<mlir::LLVMTypeConverter>::inner(tc_ptr);
        if (!tc_box) {
          return scheme_error(
              "mlir::populateFuncToLLVMConversionPatterns",
              "null pointer or not a CrestBox<mlir::LLVMTypeConverter>");
        }
        auto& tc = *tc_box;
        auto* patterns_box =
            crest::as_ref<mlir::RewritePatternSet>(patterns_ptr);
        if (!patterns_box) {
          return scheme_error(
              "mlir::populateFuncToLLVMConversionPatterns",
              "null pointer or not a CrestBox<mlir::RewritePatternSet> or "
              "CrestBox<mlir::RewritePatternSet*>");
        }
        auto& patterns = *patterns_box;
        mlir::populateFuncToLLVMConversionPatterns(tc, patterns);
        return Svoid;
      });
}

} // namespace crest

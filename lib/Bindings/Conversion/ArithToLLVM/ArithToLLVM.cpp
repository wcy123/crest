/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Conversion/ArithToLLVM/ArithToLLVM.h

#include "ArithToLLVM.h"
#include "../../Support/CrestObject.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Conversion/ArithToLLVM/ArithToLLVM.h"
#include "mlir/Conversion/LLVMCommon/TypeConverter.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

void registerConversionArithToLLVMBindings() {
  // mlir::arith::populateArithToLLVMConversionPatterns
  // (type-converter-ptr patterns-ptr) → void
  Sregister_symbol(
      "mlir::arith::populateArithToLLVMConversionPatterns",
      (void*)+[](uint64_t tc_ptr, uint64_t patterns_ptr) -> void {
        auto& tc = crest::as_ref<mlir::LLVMTypeConverter>(
            tc_ptr, "mlir::arith::populateArithToLLVMConversionPatterns");
        auto& patterns = crest::as_ref<mlir::RewritePatternSet>(
            patterns_ptr, "mlir::arith::populateArithToLLVMConversionPatterns");
        mlir::arith::populateArithToLLVMConversionPatterns(tc, patterns);
      });
}

} // namespace crest

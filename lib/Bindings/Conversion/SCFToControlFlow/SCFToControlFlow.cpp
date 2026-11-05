/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Conversion/SCFToControlFlow/SCFToControlFlow.h

#include "SCFToControlFlow.h"
#include "../../Support/CrestObject.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Conversion/SCFToControlFlow/SCFToControlFlow.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

void registerConversionSCFToControlFlowBindings() {
  // populateSCFToControlFlowConversionPatterns: lower SCF to cf dialect.
  // (patterns-ptr) → void
  Sregister_symbol(
      "mlir::populateSCFToControlFlowConversionPatterns",
      (void*)+[](uint64_t patterns_ptr) -> void {
        auto& patterns = crest::CrestBox<mlir::RewritePatternSet>::inner(
            patterns_ptr, "mlir::populateSCFToControlFlowConversionPatterns");
        mlir::populateSCFToControlFlowConversionPatterns(patterns);
      });
}

} // namespace crest

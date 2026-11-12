/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Conversion/SCFToControlFlow/SCFToControlFlow.h

#include "SCFToControlFlow.h"
#include "../../Support/CrestObject.h"
#include "../../Support/Result.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Conversion/SCFToControlFlow/SCFToControlFlow.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

void registerConversionSCFToControlFlowBindings() {
  // populateSCFToControlFlowConversionPatterns: lower SCF to cf dialect.
  // (patterns-ptr) → void
  register_binding(
      "mlir::populateSCFToControlFlowConversionPatterns",
      [](uint64_t patterns_ptr) -> llvm::Error {
        CREST_TRY(patterns,
                  crest::try_as_ref<mlir::RewritePatternSet>(
                      patterns_ptr,
                      "mlir::populateSCFToControlFlowConversionPatterns"));
        mlir::populateSCFToControlFlowConversionPatterns(patterns);
        return llvm::Error::success();
      });
}

} // namespace crest

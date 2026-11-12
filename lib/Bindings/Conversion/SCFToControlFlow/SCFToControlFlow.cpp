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
  Sregister_symbol(
      "mlir::populateSCFToControlFlowConversionPatterns",
      (void*)+[](uint64_t patterns_ptr) -> ptr {
        auto* patterns_box =
            crest::as_ref<mlir::RewritePatternSet>(patterns_ptr);
        if (!patterns_box) {
          return scheme_error(
              "mlir::populateSCFToControlFlowConversionPatterns",
              "null pointer or not a CrestBox<mlir::RewritePatternSet> or "
              "CrestBox<mlir::RewritePatternSet*>");
        }
        auto& patterns = *patterns_box;
        mlir::populateSCFToControlFlowConversionPatterns(patterns);
        return Svoid;
      });
}

} // namespace crest

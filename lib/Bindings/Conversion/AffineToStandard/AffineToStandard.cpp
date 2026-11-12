/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Conversion/AffineToStandard/AffineToStandard.h

#include "AffineToStandard.h"
#include "../../Support/CrestObject.h"
#include "../../Support/Result.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Conversion/AffineToStandard/AffineToStandard.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

void registerConversionAffineToStandardBindings() {
  // populateAffineToStdConversionPatterns: lower Affine to SCF/Standard.
  // (patterns-ptr) → void
  register_binding(
      "mlir::populateAffineToStdConversionPatterns",
      [](uint64_t patterns_ptr) -> llvm::Error {
        CREST_TRY(patterns, crest::try_as_ref<mlir::RewritePatternSet>(
                                patterns_ptr,
                                "mlir::populateAffineToStdConversionPatterns"));
        mlir::populateAffineToStdConversionPatterns(patterns);
        return llvm::Error::success();
      });
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Conversion/AffineToStandard/AffineToStandard.h

#include "AffineToStandard.h"
#include "../../Support/CrestObject.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Conversion/AffineToStandard/AffineToStandard.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

void registerConversionAffineToStandardBindings() {
  // populateAffineToStdConversionPatterns: lower Affine to SCF/Standard.
  // (patterns-ptr) → void
  Sregister_symbol(
      "mlir::populateAffineToStdConversionPatterns",
      (void*)+[](uint64_t patterns_ptr) -> void {
        auto& patterns = crest::as_ref<mlir::RewritePatternSet>(
            patterns_ptr, "mlir::populateAffineToStdConversionPatterns");
        mlir::populateAffineToStdConversionPatterns(patterns);
      });
}

} // namespace crest

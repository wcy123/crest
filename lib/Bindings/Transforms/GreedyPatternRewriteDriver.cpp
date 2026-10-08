/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/GreedyPatternRewriteDriver.h

#include "GreedyPatternRewriteDriver.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"

namespace crest {

void registerTransformsGreedyPatternRewriteDriverBindings() {
  Sregister_symbol(
      "mlir_transforms_greedy_pattern_rewrite_driver_apply",
      (void*)+[](uint64_t op_ptr, uint64_t patterns_ptr) -> int {
        if (!op_ptr) {
          scheme_error("mlir_transforms_greedy_pattern_rewrite_driver_apply",
                       "null op");
        }
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto& patterns = crest_owned<mlir::RewritePatternSet>(
            patterns_ptr,
            "mlir_transforms_greedy_pattern_rewrite_driver_apply");
        return mlir::succeeded(
                   mlir::applyPatternsGreedily(op, std::move(patterns)))
                   ? 1
                   : 0;
      });
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/GreedyPatternRewriteDriver.h

#include "GreedyPatternRewriteDriver.h"
#include "../Support/CrestObject.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"

namespace crest {

void registerTransformsGreedyPatternRewriteDriverBindings() {
  Sregister_symbol(
      "mlir_transforms_greedy_pattern_rewrite_driver_apply",
      (void*)+[](uint64_t op_ptr, uint64_t patterns_ptr) -> ptr {
        if (!op_ptr) {
          return scheme_error(
              "mlir_transforms_greedy_pattern_rewrite_driver_apply", "null op");
        }
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* patterns_box =
            crest::CrestBox<mlir::RewritePatternSet>::inner(patterns_ptr);
        if (!patterns_box) {
          return scheme_error(
              "mlir_transforms_greedy_pattern_rewrite_driver_apply",
              "null pointer or not a CrestBox<mlir::RewritePatternSet>");
        }
        auto& patterns = *patterns_box;
        return Sinteger64(mlir::succeeded(mlir::applyPatternsGreedily(
                              op, std::move(patterns)))
                              ? 1
                              : 0);
      });
}

} // namespace crest

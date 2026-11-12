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
  register_binding(
      "mlir_transforms_greedy_pattern_rewrite_driver_apply",
      [](uint64_t op_ptr, uint64_t patterns_ptr) -> llvm::Expected<int> {
        if (!op_ptr) {
          return fail("mlir_transforms_greedy_pattern_rewrite_driver_apply",
                      llvm::Twine("null op"));
        }
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        CREST_TRY(patterns,
                  crest::CrestBox<mlir::RewritePatternSet>::inner(
                      patterns_ptr,
                      "mlir_transforms_greedy_pattern_rewrite_driver_apply"));
        return mlir::succeeded(
                   mlir::applyPatternsGreedily(op, std::move(patterns)))
                   ? 1
                   : 0;
      });
}

} // namespace crest

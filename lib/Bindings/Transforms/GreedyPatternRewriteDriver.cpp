/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/GreedyPatternRewriteDriver.h

#include "GreedyPatternRewriteDriver.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"

static void scheme_error(const char* who, const char* msg) {
  Scall2(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring(msg));
}

extern "C" {

// mlir::applyPatternsGreedily — consumes the pattern set.
static int
mlir_transforms_greedy_pattern_rewrite_driver_apply(uint64_t op_ptr,
                                                    uint64_t patterns_ptr) {
  if (!op_ptr || !patterns_ptr) {
    scheme_error("mlir-transforms-greedy-pattern-rewrite-driver-apply",
                 "op and patterns must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto* patterns = reinterpret_cast<mlir::RewritePatternSet*>(patterns_ptr);
  return mlir::succeeded(mlir::applyPatternsGreedily(op, std::move(*patterns)))
             ? 1
             : 0;
}

} // extern "C"

namespace crest {

void registerTransformsGreedyPatternRewriteDriverBindings() {
  Sregister_symbol(
      "mlir_transforms_greedy_pattern_rewrite_driver_apply",
      (void*)::mlir_transforms_greedy_pattern_rewrite_driver_apply);
}

} // namespace crest

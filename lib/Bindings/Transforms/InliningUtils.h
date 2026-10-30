/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once
#include "../Support/CrestObject.h"
#include <memory>

namespace mlir {
class Pass;
} // namespace mlir

namespace crest {

// Holds a unique_ptr<Pass> on the Scheme side until it is consumed by
// mlir::PassManager::addPass. Calling addPass moves the pass out;
// subsequent addPass calls with the same holder will error.
struct CrestPassHolder : public AsCrest<CrestPassHolder> {
  std::unique_ptr<mlir::Pass> pass;
  explicit CrestPassHolder(std::unique_ptr<mlir::Pass> p);
};

void registerTransformsInliningUtilsBindings();

} // namespace crest

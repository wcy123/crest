/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/Passes.h

#include "Passes.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/Transforms/Passes.h"

namespace crest {

void registerTransformsPassesBindings() {
  Sregister_symbol(
      "mlir::createCanonicalizerPass", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            new CrestOwned<std::unique_ptr<mlir::Pass>>(
                mlir::createCanonicalizerPass()));
      });

  Sregister_symbol(
      "mlir::createCSEPass", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            new CrestOwned<std::unique_ptr<mlir::Pass>>(mlir::createCSEPass()));
      });
}

} // namespace crest

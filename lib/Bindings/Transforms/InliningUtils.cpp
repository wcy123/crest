/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/InliningUtils.h

#include "InliningUtils.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Transforms/Passes.h"

namespace crest {

void registerTransformsInliningUtilsBindings() {
  Sregister_symbol(
      "mlir::createInlinerPass", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            new CrestBox<std::unique_ptr<mlir::Pass>>(
                mlir::createInlinerPass()));
      });
}

} // namespace crest

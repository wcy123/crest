/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/InliningUtils.h

#include "InliningUtils.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/Transforms/Passes.h"

namespace crest {

CrestPassHolder::CrestPassHolder(std::unique_ptr<mlir::Pass> p)
    : pass(std::move(p)) {}

void registerTransformsInliningUtilsBindings() {
  Sregister_symbol(
      "mlir::createInlinerPass", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            new CrestPassHolder(mlir::createInlinerPass()));
      });
}

} // namespace crest

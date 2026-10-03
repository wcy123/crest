/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once

#include "mlir/Pass/Pass.h"

namespace crest {

/// Register --crest-pass with the global MLIR pass pipeline registry.
/// After this call, mlir-opt-style drivers accept:
///   --crest-pass="module=passes/my-rewrite"
///   --crest-pass="module=passes/my-rewrite,log-level=debug"
void registerCrestPass();

} // namespace crest

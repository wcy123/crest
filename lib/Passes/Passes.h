/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#pragma once

#include "mlir/Pass/Pass.h"

namespace crest {

#define GEN_PASS_DECL
#include "Passes.h.inc"

#define GEN_PASS_REGISTRATION
#include "Passes.h.inc"

} // namespace crest

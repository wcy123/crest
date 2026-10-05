/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Backward-compatibility entry point. The canonical implementation has moved
// to lib/Bindings/Transforms/DialectConversion.cpp.

#include "Conversion.h"
#include "../Transforms/DialectConversion.h"

namespace crest {

void registerConversionBindings() {
  registerTransformsDialectConversionBindings();
}

} // namespace crest

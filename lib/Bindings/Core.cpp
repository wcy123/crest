/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Registration hub — delegates to the focused sub-files in Core/.
// Implementations live in Core/Attribute.cpp, Core/Operation.cpp,
// Core/Value.cpp, and Core/Builder.cpp.

#include "Core/Attribute.h"
#include "Core/Builder.h"
#include "Core/Operation.h"
#include "Core/Value.h"

namespace crest {

void registerCoreBindings() {
  registerAttributeBindings();
  registerOperationBindings();
  registerValueBindings();
  registerBuilderBindings();
}

} // namespace crest

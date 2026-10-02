/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Registration hub — delegates to the focused sub-files in Core/.
// Implementations live in Core/Attribute.cpp, Core/Operation.cpp,
// Core/Value.cpp, and Core/Builder.cpp.

#include "SchemeWrapper.h"

namespace crest {

void registerAttributeBindings();
void registerOperationBindings();
void registerValueBindings();
void registerBuilderBindings();

void registerCoreBindings() {
  registerAttributeBindings();
  registerOperationBindings();
  registerValueBindings();
  registerBuilderBindings();
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Registration hub — delegates to the focused sub-files in Core/.
// Implementations live in Core/Attribute.cpp, Core/Operation.cpp,
// Core/Value.cpp, Core/Builder.cpp, and Core/Types.cpp.

#include "Attribute.h"
#include "Builder.h"
#include "Operation.h"
#include "Types.h"
#include "Value.h"

namespace crest {

void registerCoreBindings() {
  registerAttributeBindings();
  registerOperationBindings();
  registerValueBindings();
  registerBuilderBindings();
  registerTypeBindings();
}

} // namespace crest

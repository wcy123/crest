/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Registration hub — delegates to the focused sub-files in Core/.

#include "Attribute.h"
#include "Builder.h"
#include "Conversion.h"
#include "Operation.h"
#include "Types.h"
#include "Value.h"

namespace crest {

void registerCoreBindings() {
  registerAttributeBindings();
  registerBuilderBindings();
  registerConversionBindings();
  registerOperationBindings();
  registerTypeBindings();
  registerValueBindings();
}

} // namespace crest

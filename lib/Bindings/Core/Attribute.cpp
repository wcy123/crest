/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Backward-compatibility shim. Canonical implementation has moved to
// lib/Bindings/IR/BuiltinAttributes.cpp.

#include "Attribute.h"
#include "../IR/BuiltinAttributes.h"

namespace crest {

void registerAttributeBindings() { registerIRBuiltinAttributesBindings(); }

} // namespace crest

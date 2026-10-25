/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once
#include "mlir/Support/TypeID.h"
#include <memory>
#include <string>
#include <unordered_map>

namespace crest {

// ---------------------------------------------------------------------------
// Global op-interface registry.
//
// Two levels: TypeID outer (few interfaces → fast miss on unknown interface),
// op_name inner.  Values are shared_ptr<void> managing concept lifetime;
// the custom deleter unlocks any locked Scheme objects before freeing.
// ---------------------------------------------------------------------------
using InterfaceRegistry =
    std::unordered_map<mlir::TypeID,
                       std::unordered_map<std::string, std::shared_ptr<void>>>;

extern InterfaceRegistry g_interface_registry;

} // namespace crest

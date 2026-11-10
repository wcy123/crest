/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Mirrors mlir/IR/SymbolInterfaces.h
#pragma once

namespace mlir {
class DynamicOpDefinition;
namespace detail {
class InterfaceMap;
} // namespace detail
} // namespace mlir

namespace crest {
class LockedSchemeObject;

void registerIRSymbolInterfacesBindings();

// Insert the model of the interface into the map unless it is there.
void ensureSymbolOpInterface(mlir::detail::InterfaceMap& map);

// Install the interface in the definition of an op from the dispatcher of its
// :interface2 entry (lib/Crest/Op.cpp).
void attachSymbolOpInterface(mlir::DynamicOpDefinition& def,
                             const LockedSchemeObject& dispatcher);
} // namespace crest

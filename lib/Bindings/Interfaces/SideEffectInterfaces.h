/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Mirrors mlir/Interfaces/SideEffectInterfaces.h
#pragma once

namespace mlir {
class DynamicOpDefinition;
namespace detail {
class InterfaceMap;
} // namespace detail
} // namespace mlir

namespace crest {
class LockedSchemeObject;

void registerInterfacesSideEffectInterfacesBindings();

// What the trait `pure` adds: the models of the interfaces with the answers "no
// memory effects" and "always speculatable".
void addNoMemoryEffects(mlir::detail::InterfaceMap& map);
void addAlwaysSpeculatable(mlir::detail::InterfaceMap& map);

// Install the interface in the definition of an op from the dispatcher of its
// :interfaces entry (lib/Crest/Op.cpp).
void attachMemoryEffectOpInterface(mlir::DynamicOpDefinition& def,
                                   const LockedSchemeObject& dispatcher);
void attachConditionallySpeculatable(mlir::DynamicOpDefinition& def,
                                     const LockedSchemeObject& dispatcher);
} // namespace crest

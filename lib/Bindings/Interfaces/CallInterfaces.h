/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/CallInterfaces.h
#pragma once

namespace mlir {
class DynamicOpDefinition;
namespace detail {
class InterfaceMap;
} // namespace detail
} // namespace mlir

namespace crest {
class LockedSchemeObject;

void registerInterfacesCallInterfacesBindings();

// Insert the model of the interface, and the models of the interfaces it
// inherits from, into the map unless they are there.
void ensureArgAndResultAttrsOpInterface(mlir::detail::InterfaceMap& map);
void ensureCallableOpInterface(mlir::detail::InterfaceMap& map);

// Install the interface in the definition of an op from the dispatcher of its
// :interfaces entry (lib/Crest/Op.cpp).
void attachCallableOpInterface(mlir::DynamicOpDefinition& def,
                               const LockedSchemeObject& dispatcher);
void attachCallOpInterface(mlir::DynamicOpDefinition& def,
                           const LockedSchemeObject& dispatcher);
void attachArgAndResultAttrsOpInterface(mlir::DynamicOpDefinition& def,
                                        const LockedSchemeObject& dispatcher);
} // namespace crest

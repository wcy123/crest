/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Mirrors mlir/Interfaces/FunctionInterfaces.h
#pragma once

namespace mlir {
class DynamicOpDefinition;
namespace detail {
class InterfaceMap;
} // namespace detail
} // namespace mlir

namespace crest {
class LockedSchemeObject;

void registerInterfacesFunctionInterfacesBindings();

// Install the interface in the definition of an op from the dispatcher of its
// :interface2 entry (lib/Crest/Op.cpp). The models of the interfaces it
// inherits from (Symbol, ArgAndResultAttrs, Callable) go in first.
void attachFunctionOpInterface(mlir::DynamicOpDefinition& def,
                               const LockedSchemeObject& dispatcher);
} // namespace crest

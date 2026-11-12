/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Mirrors mlir/IR/SymbolInterfaces.h
#pragma once

#include <string>

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

// An op that has SymbolOpInterface (a base of FunctionOpInterface) must have
// all its clauses. Answers the text of the error when it does not, and "" when
// it does; it does not raise (see scheme_error).
std::string requireSymbolOpInterfaceClauses(mlir::DynamicOpDefinition& def,
                                            const std::string& opName);

// Install the interface in the definition of an op from the dispatcher of its
// :interfaces entry (lib/Crest/Op.cpp).
void attachSymbolOpInterface(mlir::DynamicOpDefinition& def,
                             const LockedSchemeObject& dispatcher);
} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/CallInterfaces.h
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

void registerInterfacesCallInterfacesBindings();

// Insert the model of the interface, and the models of the interfaces it
// inherits from, into the map unless they are there.
void ensureArgAndResultAttrsOpInterface(mlir::detail::InterfaceMap& map);
void ensureCallableOpInterface(mlir::detail::InterfaceMap& map);

// Install the interface in the definition of an op from the dispatcher of its
// :interfaces entry (lib/Crest/Op.cpp).
void attachCallableOpInterface(mlir::DynamicOpDefinition& def,
                               const LockedSchemeObject& dispatcher);
// An op that has CallableOpInterface must have all three clauses. Answers the
// text of the error when it does not (FunctionOpInterface adds the interface
// without them), and "" when it does. It does not raise: the caller answers it
// to Scheme after it has destroyed its objects (see Result.h).
std::string requireCallableOpInterfaceClauses(mlir::DynamicOpDefinition& def,
                                              const std::string& opName);
// An op that has ArgAndResultAttrsOpInterface (a base of the interfaces above)
// must have all its clauses. Answers the text of the error when it does not,
// and "" when it does; it does not raise.
std::string
requireArgAndResultAttrsOpInterfaceClauses(mlir::DynamicOpDefinition& def,
                                           const std::string& opName);
void attachCallOpInterface(mlir::DynamicOpDefinition& def,
                           const LockedSchemeObject& dispatcher);
void attachArgAndResultAttrsOpInterface(mlir::DynamicOpDefinition& def,
                                        const LockedSchemeObject& dispatcher);
} // namespace crest

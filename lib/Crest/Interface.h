/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once
#include "../Bindings/Support/SchemeWrapper.h"
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

// ---------------------------------------------------------------------------
// SupportedInterfaces<Interface>
//
// Declared but not defined here — each interface binding file must provide
// an explicit specialisation of CreateConcept.  A missing specialisation is
// a link error caught at build time.
//
// CreateConcept(dispatcher) is responsible for:
//   1. Querying the Scheme dispatcher for per-method lambdas.
//   2. Allocating a heap concept (or reusing a static default).
//   3. Storing shared_ptr<void> entries in g_interface_registry keyed by
//      the op name returned by dispatcher('operation_name).
// ---------------------------------------------------------------------------
template <typename Interface> struct SupportedInterfaces {
  static void CreateConcept(ptr dispatcher); // undefined by design
};

// ---------------------------------------------------------------------------
// Concept-creator dispatch table.
//
// Maps TypeID → SupportedInterfaces<Interface>::CreateConcept.
// Populated by registerConceptCreator() in each binding's init function.
// Looked up by crest::registerInterfaceForOperation (in Dialect.cpp).
// ---------------------------------------------------------------------------
using ConceptCreatorFn = void (*)(ptr dispatcher);
void registerConceptCreator(mlir::TypeID id, ConceptCreatorFn fn);
ConceptCreatorFn lookupConceptCreator(mlir::TypeID id); // nullptr if not found

} // namespace crest

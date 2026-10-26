/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once
#include "../Bindings/Support/SchemeWrapper.h"
#include "mlir/Support/TypeID.h"
#include <memory>
#include <string>

namespace crest {

// ---------------------------------------------------------------------------
// RegisterInterfaceForOp — insert a concept into the op-interface registry.
//
// Returns true on success, false if an entry for (id, op_name) already exists
// (no overwrite — first registration wins).
//
// The registry is a file-local static in Dialect.cpp; callers never touch it
// directly.
// ---------------------------------------------------------------------------
bool RegisterInterfaceForOp(mlir::TypeID id, const std::string& op_name,
                            std::shared_ptr<void> concept_ptr);

// ---------------------------------------------------------------------------
// SupportedInterfaces<Interface>
//
// Declared but not defined here — each interface binding file must provide
// explicit specialisations.  Missing specialisations are link errors.
//
// getOrCreateDefaultConcept() lazily creates the default concept on first
// call (C++11 function-local static, thread-safe) and returns a stable
// pointer to it.  No file-scope static globals needed.
//
// CreateConcept(dispatcher) copies the default concept, overrides the slots
// the Scheme dispatcher provides, and calls RegisterInterfaceForOp.
// ---------------------------------------------------------------------------
template <typename Interface> struct SupportedInterfaces {
  // Return a stable pointer to the (lazily created) default concept.
  static typename Interface::Concept*
  getOrCreateDefaultConcept(); // undefined by design

  // Copy the default concept, override provided slots, then register.
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

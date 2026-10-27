/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once
#include "../Bindings/Support/SchemeWrapper.h"
#include "mlir/Support/TypeID.h"
#include <cassert>
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

// Look up a registered concept by (interface TypeID, op name).
// Returns nullptr if absent.
void* LookupInterfaceForOp(mlir::TypeID id, const std::string& op_name);

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
  using ConceptType = typename Interface::Concept;
  // Lazily create the default concept, register it under ".", and return it.
  static ConceptType* getOrCreateDefaultConcept(); // undefined by design

  // Clone the concept pointed to by `from` into a new owning allocation.
  // Returns shared_ptr<void> to propagate the concrete type's custom deleter.
  static std::shared_ptr<void>
  CloneConcept(const ConceptType* from); // undefined by design

  // Copy the default concept, override provided slots, then register.
  static ConceptType* CreateConcept(ptr dispatcher); // undefined by design
};

// Return the typed concept for (Interface, op_name).
// If no op-specific entry exists, copy the default concept, register it under
// op_name, and return the new pointer.
template <typename Interface>
typename Interface::Concept* getOrCreateConcept(const std::string& op_name) {
  using ConceptType = typename Interface::Concept;
  mlir::TypeID id = Interface::getInterfaceID();
  if (void* existing = LookupInterfaceForOp(id, op_name)) {
    return static_cast<ConceptType*>(existing);
  }
  ConceptType* def =
      SupportedInterfaces<Interface>::getOrCreateDefaultConcept();
  auto cloned = SupportedInterfaces<Interface>::CloneConcept(def);
  ConceptType* cloned_ptr = static_cast<ConceptType*>(cloned.get());
  RegisterInterfaceForOp(id, op_name, std::move(cloned));
  ConceptType* registered =
      static_cast<ConceptType*>(LookupInterfaceForOp(id, op_name));
  assert(registered == cloned_ptr);
  (void)cloned_ptr;
  return registered;
}

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

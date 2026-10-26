/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once
#include "../../Crest/Interface.h"
#include "SchemeWrapper.h"
#include <string>
#include <unordered_map>

namespace crest {

// ---------------------------------------------------------------------------
// SchemeConceptHolder<Interface>
//
// Bridges a Scheme dispatch procedure into an MLIR interface concept.
//
// Layout: `concept` is the first member so that
//   reinterpret_cast<SchemeConceptHolder*>(self)
// is valid inside any concept lambda that receives `const Concept* self`.
// The lambda reads h->scheme_proc without a hash-table lookup.
//
// Lifetime: holders are heap-allocated once and intentionally leaked
// (process-lifetime resources).  Slock_object prevents GC of scheme_proc.
//
// Per-interface requirements:
//   1. Specialise the constructor to initialise the concept function pointers.
//   2. Register crest::Interface::registerConcept via Sregister_symbol.
// ---------------------------------------------------------------------------
template <typename Interface> struct SchemeConceptHolder {
  using Concept = typename Interface::Concept;

  Concept concept; // MUST be first — &holder == &holder->concept
  ptr scheme_proc;

  SchemeConceptHolder(const SchemeConceptHolder&) = delete;
  SchemeConceptHolder(SchemeConceptHolder&&) = delete;

  // Constructor body is specialised per interface in the binding .cpp file.
  // It initialises the concept function pointers so that each lambda casts
  // `self` back to SchemeConceptHolder* and calls scheme_proc.
  explicit SchemeConceptHolder(ptr proc, const Concept& default_concept);

  // Return the Concept* for op_name.  Creates a new holder (intentional leak)
  // if one does not already exist, and registers all related interfaces in the
  // global op-interface registry via registry.registerForOp.
  template <typename... SupportedInterfaces>
  static Concept* getOrCreateConcept(
      const char* op_name, ptr scheme_proc,
      SupportedInterfacesRegistry<SupportedInterfaces...>& registry) {
    auto it = g_store_.find(op_name);
    if (it == g_store_.end()) {
      Slock_object(scheme_proc);
      auto* holder = new SchemeConceptHolder<Interface>(
          scheme_proc, *DefaultConcept<Interface>::get());
      g_store_[op_name] = holder;
      registry.registerForOp(op_name, Interface::getInterfaceID(),
                             &holder->concept);
    }
    return &g_store_[op_name]->concept;
  }

private:
  static std::unordered_map<std::string, SchemeConceptHolder<Interface>*>
      g_store_;
};

template <typename Interface>
std::unordered_map<std::string, SchemeConceptHolder<Interface>*>
    SchemeConceptHolder<Interface>::g_store_;

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once
#include "mlir/Support/TypeID.h"
#include <string>
#include <unordered_map>
#include <utility>

namespace crest {

// ---------------------------------------------------------------------------
// Global op-interface registry
//
// Maps (op_name, TypeID) → raw concept pointer.
// Populated at dialect initialisation by registerOpInterface.
// Queried by CrestDialect::getRegisteredInterfaceForOp.
// ---------------------------------------------------------------------------
void registerOpInterface(const std::string& op_name, mlir::TypeID id,
                         void* concept_ptr);
void* lookupOpInterface(const std::string& op_name, mlir::TypeID id);

// ---------------------------------------------------------------------------
// DefaultConcept<Interface>
//
// Declared but NOT defined here — each interface binding file must provide
// an explicit specialisation.  A missing specialisation is a link error,
// caught at build time.
//
// Example specialisation (in FunctionInterfaces.cpp):
//   template <>
//   mlir::FunctionOpInterface::Concept*
//   crest::DefaultConcept<mlir::FunctionOpInterface>::get() {
//       return &g_function_concept;
//   }
// ---------------------------------------------------------------------------
template <typename Interface> struct DefaultConcept {
  static typename Interface::Concept* get(); // undefined by design
};

// ---------------------------------------------------------------------------
// SupportedInterfacesRegistry<Interfaces...>
//
// Knows the full set of interfaces a primary interface covers (e.g.
// FunctionOpInterface + its three sub-interfaces).  Provides:
//   getDefaultConcept(id) — lazy TypeID → concept* lookup via DefaultConcept.
//   registerForOp(op_name, primary_id, primary_concept)
//                         — registers all interfaces for one op, using
//                           primary_concept for the primary interface and
//                           DefaultConcept::get() for the rest.
// ---------------------------------------------------------------------------
template <typename... SupportedInterfaces> struct SupportedInterfacesRegistry {

  // Return the default concept* for id, nullptr if not in this registry.
  void* getDefaultConcept(mlir::TypeID id) {
    auto it = cache_.find(id);
    if (it != cache_.end()) {
      return it->second;
    }
    void* result = nullptr;
    findImpl(id, result, std::index_sequence_for<SupportedInterfaces...>{});
    if (result) {
      cache_[id] = result;
    }
    return result;
  }

  // Register all interfaces for op_name.  The interface whose TypeID equals
  // primary_id uses primary_concept; all others use their DefaultConcept.
  void registerForOp(const std::string& op_name, mlir::TypeID primary_id,
                     void* primary_concept) {
    (crest::registerOpInterface(
         op_name, SupportedInterfaces::getInterfaceID(),
         SupportedInterfaces::getInterfaceID() == primary_id
             ? primary_concept
             : DefaultConcept<SupportedInterfaces>::get()),
     ...);
  }

private:
  std::unordered_map<mlir::TypeID, void*> cache_;

  template <std::size_t... Is>
  void findImpl(mlir::TypeID id, void*& out, std::index_sequence<Is...>) {
    using Pack = std::tuple<SupportedInterfaces...>;
    ((std::tuple_element_t<Is, Pack>::getInterfaceID() == id
          ? (out = DefaultConcept<std::tuple_element_t<Is, Pack>>::get(), true)
          : false) ||
     ...);
  }
};

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once
#include "../Bindings/Support/LockedSchemeObject.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "llvm/ADT/DenseMap.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/Support/InterfaceSupport.h"
#include "mlir/Support/TypeID.h"

namespace crest {

// An op that Scheme defines gets an interface by inserting a model into the
// InterfaceMap of its DynamicOpDefinition (the attach function of the
// interface, found by its TypeID in lib/Crest/Op.cpp). A model is a struct
// derived from the Concept of the interface, with `using Interface = ...;` and
// a default constructor; the methods that Scheme implements keep the entry
// point of their callable in it, which the Concept's own function reads through
// `self`.

/// The entry point of the callable that `dispatcher` has for `method`, or null.
/// `dispatcher` is the Scheme procedure that the interface's macro answers,
/// from a method name to the entry point of a callable made once, when the
/// library of the dialect was loaded, or 0.
inline void* interfaceEntryPoint(const LockedSchemeObject& dispatcher,
                                 const char* method) {
  return reinterpret_cast<void*>(Sunsigned64_value(
      scheme_call(dispatcher.get(), Sstring_to_symbol(method))));
}

/// Install each interface of `interfaces`, the list of (TypeID . dispatcher)
/// pairs of the :interfaces entries of an op or of a dialect: the TypeID is the
/// address that the TypeID of the interface wraps, and `attachFns` finds the
/// function that installs the interface in `target`. `interfaces` is locked by
/// the caller; each dispatcher is locked while its interface is attached.
template <typename Target, typename AttachFn>
void attachInterfaces(Target& target, const LockedSchemeObject& interfaces,
                      const llvm::DenseMap<mlir::TypeID, AttachFn>& attachFns,
                      const char* who) {
  // Attaching calls Scheme, which can move the objects that the list points to,
  // so each pair is read again from the list, which is locked.
  for (iptr i = 0;; ++i) {
    ptr tail = interfaces.get();
    for (iptr k = 0; k < i && Spairp(tail); ++k) {
      tail = Scdr(tail);
    }
    if (!Spairp(tail)) {
      return;
    }
    ptr pair = Scar(tail);
    mlir::TypeID id = mlir::TypeID::getFromOpaquePointer(
        reinterpret_cast<const void*>(Sunsigned64_value(Scar(pair))));
    LockedSchemeObject dispatcher(Scdr(pair));
    auto attach = attachFns.find(id);
    if (attach == attachFns.end()) {
      scheme_error(who, "no way to install an interface of :interfaces");
    }
    attach->second(target, dispatcher);
  }
}

/// Insert `Model` unless the map has its interface already. The interfaces that
/// inherit from another one (FunctionOpInterface from SymbolOpInterface, ...)
/// need the base in the map first: MLIR's Concept looks it up when the model is
/// inserted.
template <typename Model>
void insertModelOnce(mlir::detail::InterfaceMap& map) {
  if (!map.lookup<typename Model::Interface>()) {
    map.insertModels<Model>();
  }
}

/// The Concept of `Interface` in the interface map of `op`'s registered name,
/// or null when the op does not have the interface.
template <typename Interface>
typename Interface::Concept* lookupConcept(mlir::Operation* op) {
  std::optional<mlir::RegisteredOperationName> info =
      op->getName().getRegisteredInfo();
  return info ? info->getInterface<Interface>() : nullptr;
}

} // namespace crest

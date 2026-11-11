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
#include <type_traits>
#include <utility>

namespace crest {

// An op that Scheme defines gets an interface by inserting a model into the
// InterfaceMap of its DynamicOpDefinition (the attach function of the
// interface, found by its TypeID in lib/Crest/Op.cpp). The model is
// CrestModel<mlir::XInterface>: the Concept of the interface, a table of
// function pointers that MLIR calls, with every slot null. There is no default
// implementation: the op gives the methods, as the op class does in C++.
//
// A method that Scheme implements has a callable that Scheme made once, when
// the library was loaded, and the callable goes into the slot itself
// (installInterfaceEntry), so MLIR calls Scheme directly. The callable has the
// prototype of the slot as a C function: the `const Concept*` that MLIR passes
// first (ignored), then the arguments. A class that C++ passes or returns by
// value is a number, a pointer or a struct for the C function, as the ABI of
// the platform says: Scheme writes the prototype with that in mind.

/// The model of `InterfaceT` for an op that Scheme defines: its Concept, with
/// the alias `InterfaceMap::insertModels` asks for. Every slot is null until
/// something fills it (installInterfaceEntry does). A model that still has
/// defaults derives from this and gives them to the constructor in the order of
/// the slots, which are the members of the Concept, or assigns them in its own
/// constructor; the arguments are those of the Concept's aggregate
/// initialization, so a lambda without captures converts to its slot.
template <typename InterfaceT> struct CrestModel : InterfaceT::Concept {
  using Interface = InterfaceT;
  using Concept = typename InterfaceT::Concept;

  CrestModel() = default;

  template <typename... Args,
            typename = std::enable_if_t<(sizeof...(Args) > 0)>>
  explicit CrestModel(Args&&... args) : Concept{std::forward<Args>(args)...} {}
};

/// The entry point of the callable that `dispatcher` has for `method`, as the
/// function pointer type `Fn`, or null. `dispatcher` is the Scheme procedure
/// that the interface's macro answers, from a method name to the entry point of
/// a callable made once, when the library of the dialect was loaded, or 0.
/// `Fn` must be the prototype of that callable: Scheme and C++ each write it.
template <typename Fn>
Fn interfaceEntryPoint(const LockedSchemeObject& dispatcher,
                       const char* method) {
  static_assert(std::is_pointer_v<Fn> &&
                    std::is_function_v<std::remove_pointer_t<Fn>>,
                "an entry point is a pointer to a function");
  return reinterpret_cast<Fn>(Sunsigned64_value(
      scheme_call(dispatcher.get(), Sstring_to_symbol(method))));
}

/// Put the entry point that `dispatcher` has for `method` into `slot`, a
/// function pointer of a Concept (or of a model) whose type is the prototype of
/// the callable, and answer whether there was one. A method without a clause
/// keeps what `slot` holds, the default. The slot is called by MLIR itself, so
/// the Scheme callable takes the arguments of the slot, `const Concept* self`
/// first, and ignores `self`.
template <typename Fn>
bool installInterfaceEntry(Fn& slot, const LockedSchemeObject& dispatcher,
                           const char* method) {
  if (Fn entry = interfaceEntryPoint<Fn>(dispatcher, method)) {
    slot = entry;
    return true;
  }
  return false;
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

/// Insert `CrestModel<InterfaceT>`, with every slot null, unless the map has
/// the interface already. The interfaces that inherit from another one
/// (FunctionOpInterface from SymbolOpInterface, ...) need the base in the map
/// first: MLIR's Concept looks it up when the model is inserted.
template <typename InterfaceT>
void insertModelOnce(mlir::detail::InterfaceMap& map) {
  if (!map.lookup<InterfaceT>()) {
    map.insertModels<CrestModel<InterfaceT>>();
  }
}

/// Insert `Model`, a model of its own that has defaults, unless the map has its
/// interface already.
template <typename Model>
void insertCustomModelOnce(mlir::detail::InterfaceMap& map) {
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

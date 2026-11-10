/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once
#include "../Bindings/Support/LockedSchemeObject.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/Support/InterfaceSupport.h"

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

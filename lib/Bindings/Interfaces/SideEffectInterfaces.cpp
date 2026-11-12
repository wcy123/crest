/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/SideEffectInterfaces.h

#include "SideEffectInterfaces.h"
#include "../../Crest/Interface.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"
#include <memory>

namespace {

using MemoryEffectConcept = mlir::MemoryEffectOpInterface::Concept;
using SpeculatableConcept = mlir::ConditionallySpeculatable::Concept;

// The function that stands for "no memory effects": what the trait `pure`
// puts in the slot, and what the clause (getEffects :none) names.
void noMemoryEffects(
    const MemoryEffectConcept*, mlir::Operation*,
    llvm::SmallVectorImpl<
        mlir::SideEffects::EffectInstance<mlir::MemoryEffects::Effect>>&) {}

// The same for "always speculatable".
mlir::Speculation::Speculatability
alwaysSpeculatable(const SpeculatableConcept*, mlir::Operation*) {
  return mlir::Speculation::Speculatable;
}

} // anonymous namespace

namespace crest {

// The trait `pure` means no memory effects and always speculatable: it fills
// the slots with those answers, which are its definition. A clause of the op
// for the interface replaces them.
void addNoMemoryEffects(mlir::detail::InterfaceMap& map) {
  insertModelOnce<mlir::MemoryEffectOpInterface>(map);
  map.lookup<mlir::MemoryEffectOpInterface>()->getEffects = noMemoryEffects;
}

void addAlwaysSpeculatable(mlir::detail::InterfaceMap& map) {
  insertModelOnce<mlir::ConditionallySpeculatable>(map);
  map.lookup<mlir::ConditionallySpeculatable>()->getSpeculatability =
      alwaysSpeculatable;
}

void attachMemoryEffectOpInterface(mlir::DynamicOpDefinition& def,
                                   const LockedSchemeObject& dispatcher) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  insertModelOnce<mlir::MemoryEffectOpInterface>(map);
  installInterfaceEntry(map.lookup<mlir::MemoryEffectOpInterface>()->getEffects,
                        dispatcher, "getEffects");
}

void attachConditionallySpeculatable(mlir::DynamicOpDefinition& def,
                                     const LockedSchemeObject& dispatcher) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  insertModelOnce<mlir::ConditionallySpeculatable>(map);
  installInterfaceEntry(
      map.lookup<mlir::ConditionallySpeculatable>()->getSpeculatability,
      dispatcher, "getSpeculatability");
}

void registerInterfacesSideEffectInterfacesBindings() {
  // mlir::MemoryEffectOpInterface::getInterfaceID () -> uptr
  // mlir::ConditionallySpeculatable::getInterfaceID () -> uptr
  //
  // The address that the TypeID of the interface wraps, which C++ turns back
  // with TypeID::getFromOpaquePointer to find how to install the interface.
  register_binding("mlir::MemoryEffectOpInterface::getInterfaceID",
                   []() -> uint64_t {
                     return reinterpret_cast<uint64_t>(
                         mlir::MemoryEffectOpInterface::getInterfaceID()
                             .getAsOpaquePointer());
                   });
  // crest::MemoryEffectOpInterface::noEffects () -> uptr
  //
  // The address of the C function that stands for "no memory effects", for the
  // clause (getEffects :none).
  register_binding("crest::MemoryEffectOpInterface::noEffects",
                   []() -> uint64_t {
                     return reinterpret_cast<uint64_t>(&noMemoryEffects);
                   });
  register_binding("mlir::ConditionallySpeculatable::getInterfaceID",
                   []() -> uint64_t {
                     return reinterpret_cast<uint64_t>(
                         mlir::ConditionallySpeculatable::getInterfaceID()
                             .getAsOpaquePointer());
                   });
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/SideEffectInterfaces.h

#include "SideEffectInterfaces.h"
#include "../../Crest/Interface.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"
#include <memory>

namespace {
// Both interfaces are answered once and for all: the op has no memory effects
// and may be speculated. This is what `pure` means; an op that wants anything
// else does not declare them.
struct MemoryEffectConceptData
    : public crest::CrestModel<mlir::MemoryEffectOpInterface> {
  MemoryEffectConceptData()
      : CrestModel{
            [](const mlir::MemoryEffectOpInterface::Concept*, mlir::Operation*,
               llvm::SmallVectorImpl<mlir::SideEffects::EffectInstance<
                   mlir::MemoryEffects::Effect>>&) {},
        } {}
};

struct SpeculatableConceptData
    : public crest::CrestModel<mlir::ConditionallySpeculatable> {
  SpeculatableConceptData()
      : CrestModel{
            [](const mlir::ConditionallySpeculatable::Concept*,
               mlir::Operation*) -> mlir::Speculation::Speculatability {
              return mlir::Speculation::Speculatable;
            },
        } {}
};

} // anonymous namespace

namespace crest {

void ensureMemoryEffectOpInterface(mlir::detail::InterfaceMap& map) {
  insertCustomModelOnce<MemoryEffectConceptData>(map);
}

void ensureConditionallySpeculatable(mlir::detail::InterfaceMap& map) {
  insertCustomModelOnce<SpeculatableConceptData>(map);
}

void attachMemoryEffectOpInterface(mlir::DynamicOpDefinition& def,
                                   const LockedSchemeObject&) {
  ensureMemoryEffectOpInterface(def.getInterfaceMap());
}

void attachConditionallySpeculatable(mlir::DynamicOpDefinition& def,
                                     const LockedSchemeObject&) {
  ensureConditionallySpeculatable(def.getInterfaceMap());
}

void registerInterfacesSideEffectInterfacesBindings() {
  // mlir::MemoryEffectOpInterface::getInterfaceID () -> uptr
  // mlir::ConditionallySpeculatable::getInterfaceID () -> uptr
  //
  // The address that the TypeID of the interface wraps, which C++ turns back
  // with TypeID::getFromOpaquePointer to find how to install the interface.
  Sregister_symbol(
      "mlir::MemoryEffectOpInterface::getInterfaceID",
      (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::MemoryEffectOpInterface::getInterfaceID()
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::ConditionallySpeculatable::getInterfaceID",
      (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::ConditionallySpeculatable::getInterfaceID()
                .getAsOpaquePointer());
      });
}

} // namespace crest

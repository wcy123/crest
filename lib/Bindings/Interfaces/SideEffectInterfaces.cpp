/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/SideEffectInterfaces.h

#include "SideEffectInterfaces.h"
#include "../../Crest/Interface.h"
#include "../Support/LockedSchemeObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"
#include <memory>

namespace {
// Both interfaces are answered once and for all: the op has no memory effects
// and may be speculated. This is what `pure` means; an op that wants anything
// else does not declare them.
struct MemoryEffectConceptData : public mlir::MemoryEffectOpInterface::Concept {
  MemoryEffectConceptData()
      : mlir::MemoryEffectOpInterface::Concept{
            [](const mlir::MemoryEffectOpInterface::Concept*, mlir::Operation*,
               llvm::SmallVectorImpl<mlir::SideEffects::EffectInstance<
                   mlir::MemoryEffects::Effect>>&) {},
        } {}
};

struct SpeculatableConceptData
    : public mlir::ConditionallySpeculatable::Concept {
  SpeculatableConceptData()
      : mlir::ConditionallySpeculatable::Concept{
            [](const mlir::ConditionallySpeculatable::Concept*,
               mlir::Operation*) -> mlir::Speculation::Speculatability {
              return mlir::Speculation::Speculatable;
            },
        } {}
};

template <typename Interface, typename Data>
typename Interface::Concept* createConcept(ptr dispatcher) {
  crest::LockedSchemeObject locked_dispatcher(dispatcher);
  std::string op_name = Conversion<ptr, std::string>{}(
      scheme_call(dispatcher, Sstring_to_symbol("operation_name")));
  auto data = std::make_unique<Data>();
  Data* raw = data.get();
  crest::RegisterInterfaceForOp(
      Interface::getInterfaceID(), op_name,
      std::shared_ptr<void>(data.release(),
                            [](void* p) { delete static_cast<Data*>(p); }));
  return reinterpret_cast<typename Interface::Concept*>(raw);
}
} // anonymous namespace

namespace crest {

template <>
mlir::MemoryEffectOpInterface::Concept* SupportedInterfaces<
    mlir::MemoryEffectOpInterface>::getOrCreateDefaultConcept() {
  static mlir::MemoryEffectOpInterface::Concept* ptr = [] {
    return getOrCreateDefaultConcept(
        std::make_unique<MemoryEffectConceptData>());
  }();
  return ptr;
}

template <>
mlir::ConditionallySpeculatable::Concept* SupportedInterfaces<
    mlir::ConditionallySpeculatable>::getOrCreateDefaultConcept() {
  static mlir::ConditionallySpeculatable::Concept* ptr = [] {
    return getOrCreateDefaultConcept(
        std::make_unique<SpeculatableConceptData>());
  }();
  return ptr;
}

template <>
std::shared_ptr<void>
SupportedInterfaces<mlir::MemoryEffectOpInterface>::CloneConcept(
    const mlir::MemoryEffectOpInterface::Concept* from) {
  const auto* src = static_cast<const MemoryEffectConceptData*>(from);
  return std::shared_ptr<void>(new MemoryEffectConceptData(*src), [](void* p) {
    delete static_cast<MemoryEffectConceptData*>(p);
  });
}

template <>
std::shared_ptr<void>
SupportedInterfaces<mlir::ConditionallySpeculatable>::CloneConcept(
    const mlir::ConditionallySpeculatable::Concept* from) {
  const auto* src = static_cast<const SpeculatableConceptData*>(from);
  return std::shared_ptr<void>(new SpeculatableConceptData(*src), [](void* p) {
    delete static_cast<SpeculatableConceptData*>(p);
  });
}

void registerInterfacesSideEffectInterfacesBindings() {
  SupportedInterfaces<
      mlir::MemoryEffectOpInterface>::getOrCreateDefaultConcept();
  SupportedInterfaces<
      mlir::ConditionallySpeculatable>::getOrCreateDefaultConcept();
  Sregister_symbol(
      "mlir::MemoryEffectOpInterface", (void*)+[](ptr dispatcher) {
        createConcept<mlir::MemoryEffectOpInterface, MemoryEffectConceptData>(
            dispatcher);
      });
  Sregister_symbol(
      "mlir::ConditionallySpeculatable", (void*)+[](ptr dispatcher) {
        createConcept<mlir::ConditionallySpeculatable, SpeculatableConceptData>(
            dispatcher);
      });
}

} // namespace crest

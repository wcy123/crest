/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// InferTypeOpInterface for Scheme ops — lib/Crest/InferType.cpp
//
// inferReturnTypes is a static interface method: its function pointer in the
// Concept gets no Concept* and no Operation*, so one shared C++ function cannot
// tell which Scheme op it serves. Every op therefore gets a function of its
// own: Scheme makes it with foreign-callable, once, when the library of the
// dialect is loaded. The dispatcher of C of the op, which is only needed while
// the op is registered, is locked by the caller; C++ asks it for the entry
// point of each method with scheme_call.
// The Concept is a heap object in the op's InterfaceMap, so this one model
// type serves all ops and the pointer is filled in per op.

#include "InferType.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/Operation.h"
#include "mlir/Interfaces/InferTypeOpInterface.h"

namespace crest {

namespace {

// The signature differs between LLVM versions (the properties argument is an
// OpaqueProperties before LLVM 23 and a PropertyRef from LLVM 23), so take it
// from the Concept.
using InferFn = decltype(mlir::InferTypeOpInterface::Concept::inferReturnTypes);

struct DynamicInferTypeModel : public mlir::InferTypeOpInterface::Concept {
  using Interface = mlir::InferTypeOpInterface;

  // What an op gets for a method its dispatcher has no clause for. The default
  // refineReturnTypes of an ODS op calls the other two methods of the op, which
  // a function pointer without the op cannot do, so it accepts anything.
  template <typename Properties>
  static llvm::LogicalResult
  defaultRefine(mlir::MLIRContext*, std::optional<mlir::Location>,
                mlir::ValueRange, mlir::DictionaryAttr, Properties,
                mlir::RegionRange, llvm::SmallVectorImpl<mlir::Type>&) {
    return mlir::success();
  }
  static bool defaultCompatible(mlir::TypeRange lhs, mlir::TypeRange rhs) {
    return lhs == rhs;
  }

  DynamicInferTypeModel()
      : Concept{nullptr, defaultRefine, defaultCompatible} {}
};

// The entry point of the callable that `dispatcher` has for `method`, or null.
void* entryPoint(const LockedSchemeObject& dispatcher, const char* method) {
  return reinterpret_cast<void*>(Sunsigned64_value(
      scheme_call(dispatcher.get(), Sstring_to_symbol(method))));
}

} // namespace

void attachInferTypeOpInterface(mlir::DynamicOpDefinition& def,
                                const LockedSchemeObject& dispatcher) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  map.insertModels<DynamicInferTypeModel>();
  mlir::InferTypeOpInterface::Concept* concept_ =
      map.lookup<mlir::InferTypeOpInterface>();
  // The entry of each method the dispatcher has a clause for; the others keep
  // the default.
  if (void* infer = entryPoint(dispatcher, "inferReturnTypes")) {
    concept_->inferReturnTypes = reinterpret_cast<InferFn>(infer);
  }
  if (void* refine = entryPoint(dispatcher, "refineReturnTypes")) {
    concept_->refineReturnTypes =
        reinterpret_cast<decltype(concept_->refineReturnTypes)>(refine);
  }
  if (void* compatible = entryPoint(dispatcher, "isCompatibleReturnTypes")) {
    concept_->isCompatibleReturnTypes =
        reinterpret_cast<decltype(concept_->isCompatibleReturnTypes)>(
            compatible);
  }
}

} // namespace crest

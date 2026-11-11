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
#include "Interface.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/Operation.h"
#include "mlir/Interfaces/InferTypeOpInterface.h"

namespace crest {

namespace {

struct DynamicInferTypeModel : public CrestModel<mlir::InferTypeOpInterface> {
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

  // defaultRefine is a template: the slot says which instance.
  DynamicInferTypeModel() {
    refineReturnTypes = defaultRefine;
    isCompatibleReturnTypes = defaultCompatible;
  }
};

} // namespace

void attachInferTypeOpInterface(mlir::DynamicOpDefinition& def,
                                const LockedSchemeObject& dispatcher) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  map.insertModels<DynamicInferTypeModel>();
  mlir::InferTypeOpInterface::Concept* concept_ =
      map.lookup<mlir::InferTypeOpInterface>();
  // The entry of each method the dispatcher has a clause for; the others keep
  // the default.
  installInterfaceEntry(concept_->inferReturnTypes, dispatcher,
                        "inferReturnTypes");
  installInterfaceEntry(concept_->refineReturnTypes, dispatcher,
                        "refineReturnTypes");
  installInterfaceEntry(concept_->isCompatibleReturnTypes, dispatcher,
                        "isCompatibleReturnTypes");
}

} // namespace crest

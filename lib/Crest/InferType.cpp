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

// MLIR has no default for inferReturnTypes, and the macro writes the defaults
// of the other two methods in Scheme, so every slot is the callable that Scheme
// made. Each method here has no Concept* and no Operation*: MLIR calls it as a
// static function, so Scheme makes a callable per op.
void attachInferTypeOpInterface(mlir::DynamicOpDefinition& def,
                                const LockedSchemeObject& dispatcher) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  insertModelOnce<mlir::InferTypeOpInterface>(map);
  auto* concept_ = map.lookup<mlir::InferTypeOpInterface>();
  installInterfaceEntry(concept_->inferReturnTypes, dispatcher,
                        "inferReturnTypes");
  installInterfaceEntry(concept_->refineReturnTypes, dispatcher,
                        "refineReturnTypes");
  installInterfaceEntry(concept_->isCompatibleReturnTypes, dispatcher,
                        "isCompatibleReturnTypes");
}

} // namespace crest

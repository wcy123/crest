/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/CallInterfaces.h

#include "CallInterfaces.h"
#include "../../Crest/Interface.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Region.h"
#include "mlir/IR/Types.h"
#include "mlir/Interfaces/CallInterfaces.h"

namespace crest {

// ---------------------------------------------------------------------------
// SupportedInterfaces<CallableOpInterface>::getOrCreateDefaultConcept
//
// Lazily creates the default CallableOpInterface concept on first call.
// printFunctionOp uses the argument and result types extracted from the
// "function_type" attribute; getCallableRegion returns region 0.
// ---------------------------------------------------------------------------
template <>
mlir::CallableOpInterface::Concept*
SupportedInterfaces<mlir::CallableOpInterface>::getOrCreateDefaultConcept() {
  static mlir::CallableOpInterface::Concept concept {
      // getCallableRegion
      [](const mlir::CallableOpInterface::Concept*,
         mlir::Operation* op) -> mlir::Region* { return &op->getRegion(0); },
      // getArgumentTypes: from "function_type" attr
      [](const mlir::CallableOpInterface::Concept*,
         mlir::Operation* op) -> llvm::ArrayRef<mlir::Type> {
        return mlir::cast<mlir::FunctionType>(
                   mlir::cast<mlir::TypeAttr>(op->getAttr("function_type"))
                       .getValue())
            .getInputs();
      },
      // getResultTypes: from "function_type" attr
      [](const mlir::CallableOpInterface::Concept*,
         mlir::Operation* op) -> llvm::ArrayRef<mlir::Type> {
        return mlir::cast<mlir::FunctionType>(
                   mlir::cast<mlir::TypeAttr>(op->getAttr("function_type"))
                       .getValue())
            .getResults();
      },
  };
  return &concept;
}

// ---------------------------------------------------------------------------
// SupportedInterfaces<ArgAndResultAttrsOpInterface>::getOrCreateDefaultConcept
//
// ArgAndResultAttrsOpInterface is defined in mlir/Interfaces/CallInterfaces.td
// so its specialisation lives here.  printFunctionOp only calls
// getArgAttrsAttr/getResAttrsAttr; returning nullptr is safe.
// ---------------------------------------------------------------------------
template <>
mlir::ArgAndResultAttrsOpInterface::Concept* SupportedInterfaces<
    mlir::ArgAndResultAttrsOpInterface>::getOrCreateDefaultConcept() {
  static mlir::ArgAndResultAttrsOpInterface::Concept concept {
      [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
         mlir::Operation*) -> mlir::ArrayAttr { return nullptr; },
      [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
         mlir::Operation*) -> mlir::ArrayAttr { return nullptr; },
      [](const mlir::ArgAndResultAttrsOpInterface::Concept*, mlir::Operation*,
         mlir::ArrayAttr) {},
      [](const mlir::ArgAndResultAttrsOpInterface::Concept*, mlir::Operation*,
         mlir::ArrayAttr) {},
      [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
         mlir::Operation*) -> mlir::Attribute { return nullptr; },
      [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
         mlir::Operation*) -> mlir::Attribute { return nullptr; },
  };
  return &concept;
}

// ---------------------------------------------------------------------------
// Sregister_symbol bindings
// ---------------------------------------------------------------------------

void registerInterfacesCallInterfacesBindings() {
  auto no_del = [](void*) {};
  RegisterInterfaceForOp(
      mlir::CallableOpInterface::getInterfaceID(), ".",
      std::shared_ptr<void>(
          SupportedInterfaces<
              mlir::CallableOpInterface>::getOrCreateDefaultConcept(),
          no_del));
  RegisterInterfaceForOp(
      mlir::ArgAndResultAttrsOpInterface::getInterfaceID(), ".",
      std::shared_ptr<void>(
          SupportedInterfaces<
              mlir::ArgAndResultAttrsOpInterface>::getOrCreateDefaultConcept(),
          no_del));
}

} // namespace crest

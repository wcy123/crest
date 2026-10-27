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

template <>
mlir::CallableOpInterface::Concept*
SupportedInterfaces<mlir::CallableOpInterface>::getOrCreateDefaultConcept() {
  // Thread-safe (C++11): initialised once; registry owns the concept.
  static mlir::CallableOpInterface::Concept* ptr = [] {
    auto* c = new mlir::CallableOpInterface::Concept{
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
    RegisterInterfaceForOp(
        mlir::CallableOpInterface::getInterfaceID(), ".",
        std::shared_ptr<void>(c, [](void* p) {
          delete static_cast<mlir::CallableOpInterface::Concept*>(p);
        }));
    return c;
  }();
  return ptr;
}

template <>
mlir::ArgAndResultAttrsOpInterface::Concept* SupportedInterfaces<
    mlir::ArgAndResultAttrsOpInterface>::getOrCreateDefaultConcept() {
  // Thread-safe (C++11): initialised once; registry owns the concept.
  // printFunctionOp only calls getArgAttrsAttr/getResAttrsAttr; returning
  // nullptr is safe.
  static mlir::ArgAndResultAttrsOpInterface::Concept* ptr = [] {
    auto* c = new mlir::ArgAndResultAttrsOpInterface::Concept{
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
    RegisterInterfaceForOp(
        mlir::ArgAndResultAttrsOpInterface::getInterfaceID(), ".",
        std::shared_ptr<void>(c, [](void* p) {
          delete static_cast<mlir::ArgAndResultAttrsOpInterface::Concept*>(p);
        }));
    return c;
  }();
  return ptr;
}

template <>
std::shared_ptr<void>
SupportedInterfaces<mlir::CallableOpInterface>::CloneConcept(
    const mlir::CallableOpInterface::Concept* from) {
  return std::shared_ptr<void>(
      new mlir::CallableOpInterface::Concept(*from), [](void* p) {
        delete static_cast<mlir::CallableOpInterface::Concept*>(p);
      });
}

template <>
std::shared_ptr<void>
SupportedInterfaces<mlir::ArgAndResultAttrsOpInterface>::CloneConcept(
    const mlir::ArgAndResultAttrsOpInterface::Concept* from) {
  return std::shared_ptr<void>(
      new mlir::ArgAndResultAttrsOpInterface::Concept(*from), [](void* p) {
        delete static_cast<mlir::ArgAndResultAttrsOpInterface::Concept*>(p);
      });
}

void registerInterfacesCallInterfacesBindings() {
  // Trigger initialisation — registration happens inside
  // getOrCreateDefaultConcept() on first call.
  SupportedInterfaces<mlir::CallableOpInterface>::getOrCreateDefaultConcept();
  SupportedInterfaces<
      mlir::ArgAndResultAttrsOpInterface>::getOrCreateDefaultConcept();
}

} // namespace crest

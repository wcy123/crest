/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/CallInterfaces.h

#include "CallInterfaces.h"
#include "../../Crest/Interface.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Region.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/IR/Types.h"
#include "mlir/Interfaces/CallInterfaces.h"
#include <memory>

namespace {
struct CallableConceptData : public mlir::CallableOpInterface::Concept {
  using Interface = mlir::CallableOpInterface;
  using Concept = mlir::CallableOpInterface::Concept;

  // The entry point of a foreign-callable made in Scheme; nullptr keeps the
  // default implementation, which is the first region of the op.
  uint64_t (*get_callable_region)(uint64_t op) = nullptr;

  CallableConceptData()
      : mlir::CallableOpInterface::Concept{
            [](const mlir::CallableOpInterface::Concept*, mlir::Operation* op)
                -> mlir::Region* { return &op->getRegion(0); },
            [](const mlir::CallableOpInterface::Concept*,
               mlir::Operation* op) -> llvm::ArrayRef<mlir::Type> {
              return mlir::cast<mlir::FunctionType>(
                         mlir::cast<mlir::TypeAttr>(
                             op->getAttr("function_type"))
                             .getValue())
                  .getInputs();
            },
            [](const mlir::CallableOpInterface::Concept*,
               mlir::Operation* op) -> llvm::ArrayRef<mlir::Type> {
              return mlir::cast<mlir::FunctionType>(
                         mlir::cast<mlir::TypeAttr>(
                             op->getAttr("function_type"))
                             .getValue())
                  .getResults();
            },
        } {}

  // An entry of 0 leaves the default implementation of the method.
  void install(uint64_t getCallableRegionEntry) {
    if (getCallableRegionEntry != 0) {
      get_callable_region = reinterpret_cast<decltype(get_callable_region)>(
          getCallableRegionEntry);
      getCallableRegion =
          +[](const Concept* self, mlir::Operation* op) -> mlir::Region* {
        const auto* d = static_cast<const CallableConceptData*>(self);
        return reinterpret_cast<mlir::Region*>(
            d->get_callable_region(reinterpret_cast<uint64_t>(op)));
      };
    }
  }
};

// A call op's callee is its "callee" attribute, a symbol reference or (as in
// Toy) a string naming one; its arguments are all of its operands.
struct CallConceptData : public mlir::CallOpInterface::Concept {
  using Interface = mlir::CallOpInterface;
  using Concept = mlir::CallOpInterface::Concept;

  CallConceptData()
      : Concept{
            [](const Concept*,
               mlir::Operation* op) -> mlir::CallInterfaceCallable {
              mlir::Attribute callee = op->getAttr("callee");
              if (auto ref =
                      llvm::dyn_cast_or_null<mlir::SymbolRefAttr>(callee)) {
                return ref;
              }
              if (auto name =
                      llvm::dyn_cast_or_null<mlir::StringAttr>(callee)) {
                return mlir::SymbolRefAttr::get(name);
              }
              return mlir::CallInterfaceCallable();
            },
            [](const Concept*, mlir::Operation* op,
               mlir::CallInterfaceCallable callee) {
              auto ref = llvm::dyn_cast_if_present<mlir::SymbolRefAttr>(callee);
              if (!ref) {
                return;
              }
              if (llvm::isa_and_nonnull<mlir::StringAttr>(
                      op->getAttr("callee"))) {
                op->setAttr("callee", ref.getRootReference());
              } else {
                op->setAttr("callee", ref);
              }
            },
            [](const Concept*, mlir::Operation* op)
                -> mlir::Operation::operand_range { return op->getOperands(); },
            [](const Concept*,
               mlir::Operation* op) -> mlir::MutableOperandRange {
              return mlir::MutableOperandRange(op);
            },
            [](const Concept* self, mlir::Operation* op,
               mlir::SymbolTableCollection* table) -> mlir::Operation* {
              mlir::CallInterfaceCallable callable =
                  self->getCallableForCallee(self, op);
              if (auto value =
                      llvm::dyn_cast_if_present<mlir::Value>(callable)) {
                return value.getDefiningOp();
              }
              auto ref =
                  llvm::dyn_cast_if_present<mlir::SymbolRefAttr>(callable);
              if (!ref) {
                return nullptr;
              }
              return table
                         ? table->lookupNearestSymbolFrom(op, ref)
                         : mlir::SymbolTable::lookupNearestSymbolFrom(op, ref);
            },
            [](const Concept* self, mlir::Operation* op) -> mlir::Operation* {
              return self->resolveCallableInTable(self, op, nullptr);
            },
        } {}
};

struct ArgAndResultAttrsConceptData
    : public mlir::ArgAndResultAttrsOpInterface::Concept {
  using Interface = mlir::ArgAndResultAttrsOpInterface;
  // printFunctionOp only calls getArgAttrsAttr/getResAttrsAttr; nullptr is
  // safe.
  ArgAndResultAttrsConceptData()
      : mlir::ArgAndResultAttrsOpInterface::Concept{
            [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
               mlir::Operation*) -> mlir::ArrayAttr { return nullptr; },
            [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
               mlir::Operation*) -> mlir::ArrayAttr { return nullptr; },
            [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
               mlir::Operation*, mlir::ArrayAttr) {},
            [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
               mlir::Operation*, mlir::ArrayAttr) {},
            [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
               mlir::Operation*) -> mlir::Attribute { return nullptr; },
            [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
               mlir::Operation*) -> mlir::Attribute { return nullptr; },
        } {}
};
} // anonymous namespace

namespace crest {

void ensureArgAndResultAttrsOpInterface(mlir::detail::InterfaceMap& map) {
  insertModelOnce<ArgAndResultAttrsConceptData>(map);
}

// CallableOpInterface extends ArgAndResultAttrsOpInterface: the model finds the
// base in the map, so the base comes first.
void ensureCallableOpInterface(mlir::detail::InterfaceMap& map) {
  ensureArgAndResultAttrsOpInterface(map);
  insertModelOnce<CallableConceptData>(map);
}

void attachCallableOpInterface(mlir::DynamicOpDefinition& def,
                               const LockedSchemeObject& dispatcher) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  ensureCallableOpInterface(map);
  static_cast<CallableConceptData*>(map.lookup<mlir::CallableOpInterface>())
      ->install(reinterpret_cast<uint64_t>(
          interfaceEntryPoint(dispatcher, "getCallableRegion")));
}

void attachCallOpInterface(mlir::DynamicOpDefinition& def,
                           const LockedSchemeObject&) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  ensureArgAndResultAttrsOpInterface(map);
  insertModelOnce<CallConceptData>(map);
}

void attachArgAndResultAttrsOpInterface(mlir::DynamicOpDefinition& def,
                                        const LockedSchemeObject&) {
  ensureArgAndResultAttrsOpInterface(def.getInterfaceMap());
}

void registerInterfacesCallInterfacesBindings() {
  // mlir::CallableOpInterface::getInterfaceID () -> uptr
  // mlir::CallOpInterface::getInterfaceID () -> uptr
  // mlir::ArgAndResultAttrsOpInterface::getInterfaceID () -> uptr
  //
  // The address that the TypeID of the interface wraps, which C++ turns back
  // with TypeID::getFromOpaquePointer to find how to install the interface.
  Sregister_symbol(
      "mlir::CallableOpInterface::getInterfaceID", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::CallableOpInterface::getInterfaceID().getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::CallOpInterface::getInterfaceID", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::CallOpInterface::getInterfaceID().getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::ArgAndResultAttrsOpInterface::getInterfaceID",
      (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::ArgAndResultAttrsOpInterface::getInterfaceID()
                .getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::CallableOpInterface::getCallableRegion",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::CallableOpInterface>(op);
        if (!c) {
          scheme_error("mlir::CallableOpInterface::getCallableRegion",
                       "op does not implement CallableOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        return reinterpret_cast<uint64_t>(c->getCallableRegion(c, op));
      });

  Sregister_symbol(
      "mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::ArgAndResultAttrsOpInterface>(op);
        if (!c) {
          scheme_error("mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr",
                       "op does not implement ArgAndResultAttrsOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        mlir::ArrayAttr a = c->getArgAttrsAttr(c, op);
        return a ? reinterpret_cast<uint64_t>(a.getAsOpaquePointer()) : 0;
      });

  Sregister_symbol(
      "mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::ArgAndResultAttrsOpInterface>(op);
        if (!c) {
          scheme_error("mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr",
                       "op does not implement ArgAndResultAttrsOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        mlir::ArrayAttr a = c->getResAttrsAttr(c, op);
        return a ? reinterpret_cast<uint64_t>(a.getAsOpaquePointer()) : 0;
      });
}

} // namespace crest

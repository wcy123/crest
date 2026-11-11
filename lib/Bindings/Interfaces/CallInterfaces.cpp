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
#include <string>

namespace {
// A call op's callee is its "callee" attribute, a symbol reference or (as in
// Toy) a string naming one; its arguments are all of its operands.
struct CallConceptData : public crest::CrestModel<mlir::CallOpInterface> {
  CallConceptData()
      : CrestModel{
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
    : public crest::CrestModel<mlir::ArgAndResultAttrsOpInterface> {
  // printFunctionOp only calls getArgAttrsAttr/getResAttrsAttr; nullptr is
  // safe.
  ArgAndResultAttrsConceptData()
      : CrestModel{
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
  insertCustomModelOnce<ArgAndResultAttrsConceptData>(map);
}

// CallableOpInterface extends ArgAndResultAttrsOpInterface: the model finds the
// base in the map, so the base comes first. MLIR has no default for any method
// of CallableOpInterface (the op class gives them), and a dialect keeps its
// signature where it wants, so the model has none: every slot is null until the
// clauses of the op fill it.
void ensureCallableOpInterface(mlir::detail::InterfaceMap& map) {
  ensureArgAndResultAttrsOpInterface(map);
  insertModelOnce<mlir::CallableOpInterface>(map);
}

// Each method is the callable that Scheme made for its clause, in its slot.
void attachCallableOpInterface(mlir::DynamicOpDefinition& def,
                               const LockedSchemeObject& dispatcher) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  ensureCallableOpInterface(map);
  auto* concept_ = map.lookup<mlir::CallableOpInterface>();
  installInterfaceEntry(concept_->getCallableRegion, dispatcher,
                        "getCallableRegion");
  installInterfaceEntry(concept_->getArgumentTypes, dispatcher,
                        "getArgumentTypes");
  installInterfaceEntry(concept_->getResultTypes, dispatcher, "getResultTypes");
}

// FunctionOpInterface puts the model in the map as its base, so an op can have
// the interface without having given the clauses.
void requireCallableOpInterfaceClauses(mlir::DynamicOpDefinition& def,
                                       const std::string& opName) {
  auto* concept_ = def.getInterfaceMap().lookup<mlir::CallableOpInterface>();
  if (concept_ && (!concept_->getCallableRegion ||
                   !concept_->getArgumentTypes || !concept_->getResultTypes)) {
    scheme_error("crest::register-dynamic-op!",
                 "FunctionOpInterface extends CallableOpInterface, so the op "
                 "has to declare it with its three clauses:",
                 opName.c_str());
  }
}

void attachCallOpInterface(mlir::DynamicOpDefinition& def,
                           const LockedSchemeObject&) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  ensureArgAndResultAttrsOpInterface(map);
  insertCustomModelOnce<CallConceptData>(map);
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

  // crest::CallableOpInterface::keepTypes (uptr op, list types) -> uptr
  //
  // An ArrayRef<Type> that a callable of getArgumentTypes or getResultTypes
  // answers must outlive the call. This keeps the types where the context of
  // `op` owns them (as the inputs of a function type) and answers the address
  // of the first one, which the callable writes into its ArrayRef with the
  // number of types.
  Sregister_symbol(
      "crest::CallableOpInterface::keepTypes",
      (void*)+[](uint64_t op_ptr, ptr types) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        llvm::SmallVector<mlir::Type> list;
        for (ptr cur = types; cur != Snil; cur = Scdr(cur)) {
          list.push_back(mlir::Type::getFromOpaquePointer(
              reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))));
        }
        return reinterpret_cast<uint64_t>(
            mlir::FunctionType::get(op->getContext(), list, {})
                .getInputs()
                .data());
      });

  // mlir::CallableOpInterface::getArgumentTypes (uptr op) -> list of Type
  // mlir::CallableOpInterface::getResultTypes (uptr op) -> list of Type
  Sregister_symbol(
      "mlir::CallableOpInterface::getArgumentTypes",
      (void*)+[](uint64_t op_ptr) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::CallableOpInterface>(op);
        if (!c) {
          scheme_error("mlir::CallableOpInterface::getArgumentTypes",
                       "op does not implement CallableOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        llvm::SmallVector<mlir::Type> types(c->getArgumentTypes(c, op));
        ptr list = Snil;
        for (auto it = types.rbegin(); it != types.rend(); ++it) {
          list = Scons(
              Sunsigned64(reinterpret_cast<uint64_t>(it->getAsOpaquePointer())),
              list);
        }
        return list;
      });
  Sregister_symbol(
      "mlir::CallableOpInterface::getResultTypes",
      (void*)+[](uint64_t op_ptr) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::CallableOpInterface>(op);
        if (!c) {
          scheme_error("mlir::CallableOpInterface::getResultTypes",
                       "op does not implement CallableOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        llvm::SmallVector<mlir::Type> types(c->getResultTypes(c, op));
        ptr list = Snil;
        for (auto it = types.rbegin(); it != types.rend(); ++it) {
          list = Scons(
              Sunsigned64(reinterpret_cast<uint64_t>(it->getAsOpaquePointer())),
              list);
        }
        return list;
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

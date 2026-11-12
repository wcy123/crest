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

namespace crest {

// ArgAndResultAttrsOpInterface is a base of CallableOpInterface and
// CallOpInterface (and so of FunctionOpInterface), which add its model so that
// theirs can find it. Its slots stay null until the op gives them.
void ensureArgAndResultAttrsOpInterface(mlir::detail::InterfaceMap& map) {
  insertModelOnce<mlir::ArgAndResultAttrsOpInterface>(map);
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
std::string requireCallableOpInterfaceClauses(mlir::DynamicOpDefinition& def,
                                              const std::string& opName) {
  auto* concept_ = def.getInterfaceMap().lookup<mlir::CallableOpInterface>();
  if (concept_ && (!concept_->getCallableRegion ||
                   !concept_->getArgumentTypes || !concept_->getResultTypes)) {
    return "FunctionOpInterface extends CallableOpInterface, so the op has to "
           "declare it with its three clauses: " +
           opName;
  }
  return "";
}

// Each method is the callable that Scheme made for its clause, or the function
// that CREST ships when the clause names it.
void attachCallOpInterface(mlir::DynamicOpDefinition& def,
                           const LockedSchemeObject& dispatcher) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  ensureArgAndResultAttrsOpInterface(map);
  insertModelOnce<mlir::CallOpInterface>(map);
  auto* concept_ = map.lookup<mlir::CallOpInterface>();
  installInterfaceEntry(concept_->getCallableForCallee, dispatcher,
                        "getCallableForCallee");
  installInterfaceEntry(concept_->setCalleeFromCallable, dispatcher,
                        "setCalleeFromCallable");
  installInterfaceEntry(concept_->getArgOperands, dispatcher, "getArgOperands");
  installInterfaceEntry(concept_->getArgOperandsMutable, dispatcher,
                        "getArgOperandsMutable");
  installInterfaceEntry(concept_->resolveCallableInTable, dispatcher,
                        "resolveCallableInTable");
  installInterfaceEntry(concept_->resolveCallable, dispatcher,
                        "resolveCallable");
}

void attachArgAndResultAttrsOpInterface(mlir::DynamicOpDefinition& def,
                                        const LockedSchemeObject& dispatcher) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  ensureArgAndResultAttrsOpInterface(map);
  auto* concept_ = map.lookup<mlir::ArgAndResultAttrsOpInterface>();
  installInterfaceEntry(concept_->getArgAttrsAttr, dispatcher,
                        "getArgAttrsAttr");
  installInterfaceEntry(concept_->getResAttrsAttr, dispatcher,
                        "getResAttrsAttr");
  installInterfaceEntry(concept_->setArgAttrsAttr, dispatcher,
                        "setArgAttrsAttr");
  installInterfaceEntry(concept_->setResAttrsAttr, dispatcher,
                        "setResAttrsAttr");
  installInterfaceEntry(concept_->removeArgAttrsAttr, dispatcher,
                        "removeArgAttrsAttr");
  installInterfaceEntry(concept_->removeResAttrsAttr, dispatcher,
                        "removeResAttrsAttr");
}

// Another interface adds the model of ArgAndResultAttrsOpInterface as its base,
// so an op can have it without having given the clauses.
std::string
requireArgAndResultAttrsOpInterfaceClauses(mlir::DynamicOpDefinition& def,
                                           const std::string& opName) {
  auto* concept_ =
      def.getInterfaceMap().lookup<mlir::ArgAndResultAttrsOpInterface>();
  if (concept_ &&
      (!concept_->getArgAttrsAttr || !concept_->getResAttrsAttr ||
       !concept_->setArgAttrsAttr || !concept_->setResAttrsAttr ||
       !concept_->removeArgAttrsAttr || !concept_->removeResAttrsAttr)) {
    return "CallableOpInterface, CallOpInterface and FunctionOpInterface "
           "extend ArgAndResultAttrsOpInterface, so the op has to declare "
           "it (mlir::ArgAndResultAttrsOpInterface :standard keeps "
           "arg_attrs and res_attrs attributes): " +
           opName;
  }
  return "";
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
                       op->getName().getStringRef());
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
                       op->getName().getStringRef());
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

  // The functions that CREST ships for the slots that Scheme cannot write: the
  // address of each, for a clause that names it or an MLIR default.
  //
  // crest::CallOpInterface::getArgOperandsMutable () -> uptr
  //   all the operands of the op, as the arguments of the call.
  // crest::CallOpInterface::resolveCallableInTable () -> uptr
  // crest::CallOpInterface::resolveCallable () -> uptr
  //   what MLIR does by default: look the callee up as a symbol.
  Sregister_symbol(
      "crest::CallOpInterface::getArgOperandsMutable",
      (void*)+[]() -> uint64_t {
        using Concept = mlir::CallOpInterface::Concept;
        auto function = +[](const Concept*,
                            mlir::Operation* op) -> mlir::MutableOperandRange {
          return mlir::MutableOperandRange(op);
        };
        return reinterpret_cast<uint64_t>(function);
      });
  Sregister_symbol(
      "crest::CallOpInterface::resolveCallableInTable",
      (void*)+[]() -> uint64_t {
        using Concept = mlir::CallOpInterface::Concept;
        auto function =
            +[](const Concept* self, mlir::Operation* op,
                mlir::SymbolTableCollection* table) -> mlir::Operation* {
          return mlir::call_interface_impl::resolveCallable(
              mlir::CallOpInterface(op, self), table);
        };
        return reinterpret_cast<uint64_t>(function);
      });
  Sregister_symbol(
      "crest::CallOpInterface::resolveCallable", (void*)+[]() -> uint64_t {
        using Concept = mlir::CallOpInterface::Concept;
        auto function =
            +[](const Concept* self, mlir::Operation* op) -> mlir::Operation* {
          return mlir::call_interface_impl::resolveCallable(
              mlir::CallOpInterface(op, self));
        };
        return reinterpret_cast<uint64_t>(function);
      });

  // The callee of a call is a PointerUnion<SymbolRefAttr, Value>, whose first
  // word has a tag: Scheme builds and takes it apart here.
  //
  // mlir::CallInterfaceCallable::get<SymbolRefAttr> (uptr attr) -> uptr
  // mlir::CallInterfaceCallable::get<Value> (uptr value) -> uptr
  // mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr> (uptr callable) ->
  // uptr or 0 mlir::CallInterfaceCallable::dyn_cast<Value> (uptr callable) ->
  // uptr or 0
  Sregister_symbol(
      "mlir::CallInterfaceCallable::get<SymbolRefAttr>",
      (void*)+[](uint64_t attr) -> uint64_t {
        mlir::CallInterfaceCallable callable(mlir::cast<mlir::SymbolRefAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr))));
        return reinterpret_cast<uint64_t>(callable.getOpaqueValue());
      });
  Sregister_symbol(
      "mlir::CallInterfaceCallable::get<Value>",
      (void*)+[](uint64_t value) -> uint64_t {
        mlir::CallInterfaceCallable callable(mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(value)));
        return reinterpret_cast<uint64_t>(callable.getOpaqueValue());
      });
  Sregister_symbol(
      "mlir::CallInterfaceCallable::dyn_cast<SymbolRefAttr>",
      (void*)+[](uint64_t callable) -> uint64_t {
        auto opaque = mlir::CallInterfaceCallable::getFromOpaqueValue(
            reinterpret_cast<void*>(callable));
        auto ref = llvm::dyn_cast_if_present<mlir::SymbolRefAttr>(opaque);
        return ref ? reinterpret_cast<uint64_t>(ref.getAsOpaquePointer()) : 0;
      });
  Sregister_symbol(
      "mlir::CallInterfaceCallable::dyn_cast<Value>",
      (void*)+[](uint64_t callable) -> uint64_t {
        auto opaque = mlir::CallInterfaceCallable::getFromOpaqueValue(
            reinterpret_cast<void*>(callable));
        auto value = llvm::dyn_cast_if_present<mlir::Value>(opaque);
        return value ? reinterpret_cast<uint64_t>(value.getAsOpaquePointer())
                     : 0;
      });

  // crest::OperandRange::get (uptr op, unsigned start, unsigned count)
  //   -> (data . size), the pair that a callable answers for an OperandRange
  //
  // The operands of `op` from `start`, `count` of them: what getArgOperands
  // answers.
  Sregister_symbol(
      "crest::OperandRange::get",
      (void*)+[](uint64_t op_ptr, unsigned start, unsigned count) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        mlir::OperandRange range = op->getOperands().slice(start, count);
        return Scons(Sunsigned64(reinterpret_cast<uint64_t>(range.getBase())),
                     Sunsigned64(range.size()));
      });

  Sregister_symbol(
      "mlir::CallableOpInterface::getCallableRegion",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::CallableOpInterface>(op);
        if (!c) {
          scheme_error("mlir::CallableOpInterface::getCallableRegion",
                       "op does not implement CallableOpInterface:",
                       op->getName().getStringRef());
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
                       op->getName().getStringRef());
        }
        mlir::ArrayAttr a = c->getArgAttrsAttr(c, op);
        return a ? reinterpret_cast<uint64_t>(a.getAsOpaquePointer()) : 0;
      });

  // mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr (uptr op, uptr attrs)
  // -> void mlir::ArgAndResultAttrsOpInterface::setResAttrsAttr (uptr op, uptr
  // attrs) -> void mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr (uptr
  // op) -> uptr or 0 mlir::ArgAndResultAttrsOpInterface::removeResAttrsAttr
  // (uptr op) -> uptr or 0
  Sregister_symbol(
      "mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr",
      (void*)+[](uint64_t op_ptr, uint64_t attrs) -> void {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::ArgAndResultAttrsOpInterface>(op);
        if (!c) {
          scheme_error("mlir::ArgAndResultAttrsOpInterface::setArgAttrsAttr",
                       "op does not implement ArgAndResultAttrsOpInterface:",
                       op->getName().getStringRef());
        }
        c->setArgAttrsAttr(c, op,
                           mlir::cast_if_present<mlir::ArrayAttr>(
                               mlir::Attribute::getFromOpaquePointer(
                                   reinterpret_cast<const void*>(attrs))));
      });
  Sregister_symbol(
      "mlir::ArgAndResultAttrsOpInterface::setResAttrsAttr",
      (void*)+[](uint64_t op_ptr, uint64_t attrs) -> void {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::ArgAndResultAttrsOpInterface>(op);
        if (!c) {
          scheme_error("mlir::ArgAndResultAttrsOpInterface::setResAttrsAttr",
                       "op does not implement ArgAndResultAttrsOpInterface:",
                       op->getName().getStringRef());
        }
        c->setResAttrsAttr(c, op,
                           mlir::cast_if_present<mlir::ArrayAttr>(
                               mlir::Attribute::getFromOpaquePointer(
                                   reinterpret_cast<const void*>(attrs))));
      });
  Sregister_symbol(
      "mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::ArgAndResultAttrsOpInterface>(op);
        if (!c) {
          scheme_error("mlir::ArgAndResultAttrsOpInterface::removeArgAttrsAttr",
                       "op does not implement ArgAndResultAttrsOpInterface:",
                       op->getName().getStringRef());
        }
        return reinterpret_cast<uint64_t>(
            c->removeArgAttrsAttr(c, op).getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::ArgAndResultAttrsOpInterface::removeResAttrsAttr",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::ArgAndResultAttrsOpInterface>(op);
        if (!c) {
          scheme_error("mlir::ArgAndResultAttrsOpInterface::removeResAttrsAttr",
                       "op does not implement ArgAndResultAttrsOpInterface:",
                       op->getName().getStringRef());
        }
        return reinterpret_cast<uint64_t>(
            c->removeResAttrsAttr(c, op).getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::ArgAndResultAttrsOpInterface>(op);
        if (!c) {
          scheme_error("mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr",
                       "op does not implement ArgAndResultAttrsOpInterface:",
                       op->getName().getStringRef());
        }
        mlir::ArrayAttr a = c->getResAttrsAttr(c, op);
        return a ? reinterpret_cast<uint64_t>(a.getAsOpaquePointer()) : 0;
      });
}

} // namespace crest

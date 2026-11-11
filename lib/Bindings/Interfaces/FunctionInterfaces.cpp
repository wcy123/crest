/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/FunctionInterfaces.h

#include "FunctionInterfaces.h"
#include "../../Crest/Interface.h"
#include "../IR/SymbolInterfaces.h"
#include "../Support/SchemeWrapper.h"
#include "CallInterfaces.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Region.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/Interfaces/CallInterfaces.h"
#include "mlir/Interfaces/FunctionImplementation.h"
#include "mlir/Interfaces/FunctionInterfaces.h"
#include "mlir/Support/InterfaceSupport.h"
#include <memory>

// ---------------------------------------------------------------------------
// FunctionConceptData — file-local; no template, no header.
//
// Inherits from mlir::FunctionOpInterface::Concept so FunctionConceptData*
// is implicitly convertible to Concept*, and static_cast downcasts are valid.
// getFunctionType and setFunctionTypeAttr go to the callable that Scheme made
// for the clause, which is stored in the slot of the Concept itself. The other
// three methods keep the entry point in a field of this model and have a
// function of their own in the Concept: cloneTypeWith takes ranges that a C
// function cannot take by value on every platform, and the two verifiers turn
// the answer into a LogicalResult and a diagnostic. The default implementation
// stays in the Concept until a clause replaces it.
// ---------------------------------------------------------------------------
namespace {
// What a Scheme verifyBody or verifyType said: 1 is success. A Scheme error
// makes the callable report its text before it answers 0, so the diagnostic
// can carry it.
std::string g_reported_failure;

llvm::LogicalResult verifyResult(mlir::Operation* op, int answer) {
  if (answer != 0) {
    return mlir::success();
  }
  if (g_reported_failure.empty()) {
    return mlir::failure();
  }
  std::string message = std::move(g_reported_failure);
  g_reported_failure.clear();
  return op->emitOpError() << message;
}

struct FunctionConceptData : public mlir::FunctionOpInterface::Concept {
  using Interface = mlir::FunctionOpInterface;
  using Concept = mlir::FunctionOpInterface::Concept;

  uint64_t (*clone_type_with)(uint64_t op, const void* const* inputs,
                              uint64_t input_count, const void* const* results,
                              uint64_t result_count) = nullptr;
  int (*verify_body)(uint64_t op) = nullptr;
  int (*verify_type)(uint64_t op) = nullptr;

  FunctionConceptData()
      : Concept{
            [](const Concept*, mlir::Operation* op) -> mlir::Type {
              return mlir::cast<mlir::TypeAttr>(op->getAttr("function_type"))
                  .getValue();
            },
            [](const Concept*, mlir::Operation* op, mlir::TypeAttr t) {
              op->setAttr("function_type", t);
            },
            [](const Concept*, mlir::Operation* op, mlir::TypeRange inputs,
               mlir::TypeRange results) -> mlir::Type {
              return mlir::FunctionType::get(op->getContext(), inputs, results);
            },
            [](const Concept*, mlir::Operation*) -> llvm::LogicalResult {
              return mlir::success();
            },
            [](const Concept*, mlir::Operation*) -> llvm::LogicalResult {
              return mlir::success();
            }} {}

  // A method that the dispatcher has no clause for keeps its default.
  void install(const crest::LockedSchemeObject& dispatcher) {
    crest::installInterfaceEntry(getFunctionType, dispatcher,
                                 "getFunctionType");
    crest::installInterfaceEntry(setFunctionTypeAttr, dispatcher,
                                 "setFunctionTypeAttr");
    if (crest::installInterfaceEntry(clone_type_with, dispatcher,
                                     "cloneTypeWith")) {
      cloneTypeWith =
          +[](const Concept* self, mlir::Operation* op, mlir::TypeRange inputs,
              mlir::TypeRange results) -> mlir::Type {
        const auto* d = static_cast<const FunctionConceptData*>(self);
        llvm::SmallVector<const void*, 8> inputPointers;
        llvm::SmallVector<const void*, 8> resultPointers;
        for (mlir::Type t : inputs) {
          inputPointers.push_back(t.getAsOpaquePointer());
        }
        for (mlir::Type t : results) {
          resultPointers.push_back(t.getAsOpaquePointer());
        }
        return mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(
            d->clone_type_with(reinterpret_cast<uint64_t>(op),
                               inputPointers.data(), inputPointers.size(),
                               resultPointers.data(), resultPointers.size())));
      };
    }
    if (crest::installInterfaceEntry(verify_body, dispatcher, "verifyBody")) {
      verifyBody =
          +[](const Concept* self, mlir::Operation* op) -> llvm::LogicalResult {
        const auto* d = static_cast<const FunctionConceptData*>(self);
        return verifyResult(op, d->verify_body(reinterpret_cast<uint64_t>(op)));
      };
    }
    if (crest::installInterfaceEntry(verify_type, dispatcher, "verifyType")) {
      verifyType =
          +[](const Concept* self, mlir::Operation* op) -> llvm::LogicalResult {
        const auto* d = static_cast<const FunctionConceptData*>(self);
        return verifyResult(op, d->verify_type(reinterpret_cast<uint64_t>(op)));
      };
    }
  }
};
} // anonymous namespace

namespace crest {

void attachFunctionOpInterface(mlir::DynamicOpDefinition& def,
                               const LockedSchemeObject& dispatcher) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  // The Concept of FunctionOpInterface looks its three bases up in the map when
  // the model is inserted.
  ensureSymbolOpInterface(map);
  ensureArgAndResultAttrsOpInterface(map);
  ensureCallableOpInterface(map);
  insertModelOnce<FunctionConceptData>(map);
  static_cast<FunctionConceptData*>(map.lookup<mlir::FunctionOpInterface>())
      ->install(dispatcher);
}

namespace {
// What printFunctionOp uses for an op that is not declared a
// FunctionOpInterface (Toy ch2 and ch3): the default methods, over a map of its
// own with the bases they need.
mlir::FunctionOpInterface::Concept* defaultFunctionConcept() {
  static mlir::detail::InterfaceMap map = [] {
    mlir::detail::InterfaceMap m;
    ensureSymbolOpInterface(m);
    ensureCallableOpInterface(m);
    insertModelOnce<FunctionConceptData>(m);
    return m;
  }();
  return map.lookup<mlir::FunctionOpInterface>();
}
} // namespace

void registerInterfacesFunctionInterfacesBindings() {
  // mlir::FunctionOpInterface::getInterfaceID () -> uptr
  //
  // The address that the TypeID of the interface wraps, which C++ turns back
  // with TypeID::getFromOpaquePointer to find how to install the interface.
  Sregister_symbol(
      "mlir::FunctionOpInterface::getInterfaceID", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::FunctionOpInterface::getInterfaceID().getAsOpaquePointer());
      });

  // crest::FunctionOpInterface::reportFailure (string message)
  //
  // The callable of a verifier calls it with the text of the error its Scheme
  // method raised, before it answers failure, so that the diagnostic shows it.
  Sregister_symbol(
      "crest::FunctionOpInterface::reportFailure",
      (void*)+[](const char* message) -> void {
        g_reported_failure = message;
      });

  Sregister_symbol(
      "mlir::function_interface_impl::parseFunctionOp",
      (void*)+[](uint64_t parser_ptr, uint64_t state_ptr) -> int {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        auto typeBuilder = [](mlir::Builder& builder,
                              llvm::ArrayRef<mlir::Type> argTypes,
                              llvm::ArrayRef<mlir::Type> resTypes,
                              mlir::function_interface_impl::VariadicFlag,
                              std::string&) -> mlir::Type {
          return builder.getFunctionType(argTypes, resTypes);
        };
        return !mlir::function_interface_impl::parseFunctionOp(
            *p, state, /*allowVariadic=*/false,
            mlir::StringAttr::get(state.getContext(), "function_type"),
            typeBuilder, mlir::StringAttr::get(state.getContext(), "arg_attrs"),
            mlir::StringAttr::get(state.getContext(), "res_attrs"));
      });

  Sregister_symbol(
      "mlir::function_interface_impl::printFunctionOp",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::FunctionOpInterface>(op);
        if (!c) {
          c = defaultFunctionConcept();
        }
        mlir::FunctionOpInterface fn(op, c);
        auto* ctx = op->getContext();
        mlir::function_interface_impl::printFunctionOp(
            *p, fn, /*isVariadic=*/false, "function_type",
            mlir::StringAttr::get(ctx, "arg_attrs"),
            mlir::StringAttr::get(ctx, "res_attrs"));
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::getFunctionType",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto name_str = op->getName().getStringRef().str();
        auto* c = lookupConcept<mlir::FunctionOpInterface>(op);
        if (!c) {
          scheme_error(
              "mlir::FunctionOpInterface::getFunctionType",
              "op does not implement FunctionOpInterface:", name_str.c_str());
        }
        return reinterpret_cast<uint64_t>(
            c->getFunctionType(c, op).getAsOpaquePointer());
      });

  // mlir::FunctionOpInterface::cloneTypeWith (uptr op) (list inputs) (list
  // results) -> uptr Type: the function type of the op with these inputs and
  // results, as the Concept of the op says (the default is a FunctionType).
  Sregister_symbol(
      "mlir::FunctionOpInterface::cloneTypeWith",
      (void*)+[](uint64_t op_ptr, ptr inputs, ptr results) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::FunctionOpInterface>(op);
        if (!c) {
          scheme_error("mlir::FunctionOpInterface::cloneTypeWith",
                       "op does not implement FunctionOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        llvm::SmallVector<mlir::Type> inputTypes, resultTypes;
        for (ptr cur = inputs; cur != Snil; cur = Scdr(cur)) {
          inputTypes.push_back(mlir::Type::getFromOpaquePointer(
              reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))));
        }
        for (ptr cur = results; cur != Snil; cur = Scdr(cur)) {
          resultTypes.push_back(mlir::Type::getFromOpaquePointer(
              reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))));
        }
        return reinterpret_cast<uint64_t>(
            c->cloneTypeWith(c, op, inputTypes, resultTypes)
                .getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::setFunctionTypeAttr",
      (void*)+[](uint64_t op_ptr, uint64_t attr_ptr) -> void {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::FunctionOpInterface>(op);
        if (!c) {
          scheme_error("mlir::FunctionOpInterface::setFunctionTypeAttr",
                       "op does not implement FunctionOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        mlir::TypeAttr t =
            mlir::cast<mlir::TypeAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
        c->setFunctionTypeAttr(c, op, t);
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::verifyBody",
      (void*)+[](uint64_t op_ptr) -> int {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::FunctionOpInterface>(op);
        if (!c) {
          scheme_error("mlir::FunctionOpInterface::verifyBody",
                       "op does not implement FunctionOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        return mlir::succeeded(c->verifyBody(c, op)) ? 1 : 0;
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::verifyType",
      (void*)+[](uint64_t op_ptr) -> int {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::FunctionOpInterface>(op);
        if (!c) {
          scheme_error("mlir::FunctionOpInterface::verifyType",
                       "op does not implement FunctionOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        return mlir::succeeded(c->verifyType(c, op)) ? 1 : 0;
      });
}

} // namespace crest

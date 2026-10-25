/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/FunctionInterfaces.h

#include "FunctionInterfaces.h"
#include "../../Crest/Interface.h"
#include "../IR/SymbolTable.h"
#include "../Support/SchemeWrapper.h"
#include "CallInterfaces.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Region.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/Interfaces/CallInterfaces.h"
#include "mlir/Interfaces/FunctionImplementation.h"
#include "mlir/Interfaces/FunctionInterfaces.h"
#include "mlir/Support/InterfaceSupport.h"

namespace crest {

// ---------------------------------------------------------------------------
// SupportedInterfaces<FunctionOpInterface>::getOrCreateDefaultConcept
//
// User-facing interface - declared in Interface.h, specialised here.
// Stores base-interface pointers from the three helpers above.
// ---------------------------------------------------------------------------
template <>
mlir::FunctionOpInterface::Concept* crest::SupportedInterfaces<
    mlir::FunctionOpInterface>::getOrCreateDefaultConcept() {
  // Thread-safe (C++11): initialised once; registry owns the concept.
  // Sub-interface getOrCreateDefaultConcept() calls trigger their own
  // registration before this concept is stored.
  static mlir::FunctionOpInterface::Concept* ptr = [] {
    auto* c = new mlir::FunctionOpInterface::Concept{
        // getFunctionType: read "function_type" TypeAttr
        [](const mlir::FunctionOpInterface::Concept*,
           mlir::Operation* op) -> mlir::Type {
          return mlir::cast<mlir::TypeAttr>(op->getAttr("function_type"))
              .getValue();
        },
        // setFunctionTypeAttr
        [](const mlir::FunctionOpInterface::Concept*, mlir::Operation* op,
           mlir::TypeAttr t) { op->setAttr("function_type", t); },
        // cloneTypeWith
        [](const mlir::FunctionOpInterface::Concept*, mlir::Operation* op,
           mlir::TypeRange inputs, mlir::TypeRange results) -> mlir::Type {
          return mlir::FunctionType::get(op->getContext(), inputs, results);
        },
        // verifyBody / verifyType: always succeed
        [](const mlir::FunctionOpInterface::Concept*,
           mlir::Operation*) -> llvm::LogicalResult { return mlir::success(); },
        [](const mlir::FunctionOpInterface::Concept*,
           mlir::Operation*) -> llvm::LogicalResult { return mlir::success(); },
        // base interface pointers - set directly (initializeInterfaceConcept
        // is not called via getRegisteredInterfaceForOp)
        SupportedInterfaces<
            mlir::SymbolOpInterface>::getOrCreateDefaultConcept(),
        SupportedInterfaces<
            mlir::ArgAndResultAttrsOpInterface>::getOrCreateDefaultConcept(),
        SupportedInterfaces<
            mlir::CallableOpInterface>::getOrCreateDefaultConcept(),
    };
    RegisterInterfaceForOp(
        mlir::FunctionOpInterface::getInterfaceID(), ".",
        std::shared_ptr<void>(c, [](void* p) {
          delete static_cast<mlir::FunctionOpInterface::Concept*>(p);
        }));
    return c;
  }();
  return ptr;
}

// Static override lambdas - non-capturing; use self == FunctionConceptData*
// to reach the per-op Scheme lambdas stored alongside the concept.
namespace {
using FopConcept = mlir::FunctionOpInterface::Concept;

// Marshal a TypeRange to a Scheme list of uptr (one per mlir::Type opaque ptr).
ptr typeRangeToSchemeList(mlir::TypeRange range) {
  ptr list = Snil;
  for (auto it = range.rbegin(); it != range.rend(); ++it) {
    list =
        Scons(Sunsigned64(reinterpret_cast<uint64_t>(it->getAsOpaquePointer())),
              list);
  }
  return list;
}
const auto k_override_getFunctionType =
    +[](const FopConcept* self, mlir::Operation* op) -> mlir::Type {
  const auto* d = reinterpret_cast<const FunctionConceptData*>(self);
  ptr r = scheme_call(d->get_function_type, reinterpret_cast<uint64_t>(op));
  return mlir::Type::getFromOpaquePointer(
      reinterpret_cast<const void*>(Sunsigned64_value(r)));
};
const auto k_override_setFunctionTypeAttr =
    +[](const FopConcept* self, mlir::Operation* op, mlir::TypeAttr t) {
      const auto* d = reinterpret_cast<const FunctionConceptData*>(self);
      scheme_call(d->set_function_type_attr, reinterpret_cast<uint64_t>(op),
                  reinterpret_cast<uint64_t>(t.getAsOpaquePointer()));
    };
const auto k_override_verifyBody =
    +[](const FopConcept* self, mlir::Operation* op) -> llvm::LogicalResult {
  const auto* d = reinterpret_cast<const FunctionConceptData*>(self);
  ptr r = scheme_call(d->verify_body, reinterpret_cast<uint64_t>(op));
  return r == Strue ? mlir::success() : mlir::failure();
};
const auto k_override_cloneTypeWith =
    +[](const FopConcept* self, mlir::Operation* op, mlir::TypeRange inputs,
        mlir::TypeRange results) -> mlir::Type {
  const auto* d = reinterpret_cast<const FunctionConceptData*>(self);
  ptr r = scheme_call(d->clone_type_with, reinterpret_cast<uint64_t>(op),
                      typeRangeToSchemeList(inputs),
                      typeRangeToSchemeList(results));
  return mlir::Type::getFromOpaquePointer(
      reinterpret_cast<const void*>(Sunsigned64_value(r)));
};
const auto k_override_verifyType =
    +[](const FopConcept* self, mlir::Operation* op) -> llvm::LogicalResult {
  const auto* d = reinterpret_cast<const FunctionConceptData*>(self);
  ptr r = scheme_call(d->verify_type, reinterpret_cast<uint64_t>(op));
  return r == Strue ? mlir::success() : mlir::failure();
};
} // anonymous namespace

// CreateConcept - copies the default concept, overrides named slots for each
// method the dispatcher provides, then registers via RegisterInterfaceForOp.
template <>
void crest::SupportedInterfaces<mlir::FunctionOpInterface>::CreateConcept(
    ptr dispatcher) {
  std::string op_name{Sstring_value(
      scheme_call(dispatcher, Sstring_to_symbol("operation_name")))};

  ptr getFunctionType =
      scheme_call(dispatcher, Sstring_to_symbol("getFunctionType"));
  ptr setFunctionTypeAttr =
      scheme_call(dispatcher, Sstring_to_symbol("setFunctionTypeAttr"));
  ptr cloneTypeWith =
      scheme_call(dispatcher, Sstring_to_symbol("cloneTypeWith"));
  ptr verifyBody = scheme_call(dispatcher, Sstring_to_symbol("verifyBody"));
  ptr verifyType = scheme_call(dispatcher, Sstring_to_symbol("verifyType"));
  bool has_override =
      (getFunctionType != Sfalse || setFunctionTypeAttr != Sfalse ||
       cloneTypeWith != Sfalse || verifyBody != Sfalse || verifyType != Sfalse);

  if (has_override) {
    // Copy default; override only the provided slots by field name.
    auto* data = new FunctionConceptData{
        *getOrCreateDefaultConcept(), Sfalse, Sfalse, Sfalse, Sfalse, Sfalse};
    if (getFunctionType != Sfalse) {
      Slock_object(getFunctionType);
      data->get_function_type = getFunctionType;
      data->concept.getFunctionType = k_override_getFunctionType;
    }
    if (setFunctionTypeAttr != Sfalse) {
      Slock_object(setFunctionTypeAttr);
      data->set_function_type_attr = setFunctionTypeAttr;
      data->concept.setFunctionTypeAttr = k_override_setFunctionTypeAttr;
    }
    if (cloneTypeWith != Sfalse) {
      Slock_object(cloneTypeWith);
      data->clone_type_with = cloneTypeWith;
      data->concept.cloneTypeWith = k_override_cloneTypeWith;
    }
    if (verifyBody != Sfalse) {
      Slock_object(verifyBody);
      data->verify_body = verifyBody;
      data->concept.verifyBody = k_override_verifyBody;
    }
    if (verifyType != Sfalse) {
      Slock_object(verifyType);
      data->verify_type = verifyType;
      data->concept.verifyType = k_override_verifyType;
    }
    crest::RegisterInterfaceForOp(
        mlir::FunctionOpInterface::getInterfaceID(), op_name,
        std::shared_ptr<void>(data, [](void* p) {
          auto* d = static_cast<FunctionConceptData*>(p);
          for (ptr sv : {d->get_function_type, d->set_function_type_attr,
                         d->clone_type_with, d->verify_body, d->verify_type}) {
            if (sv != Sfalse) {
              Sunlock_object(sv);
            }
          }
          delete d;
        }));
  }
  // No-override case: nothing to register - "." fallback handles all
  // interfaces for this op via getRegisteredInterfaceForOp.
}

// Sregister_symbol bindings
// ---------------------------------------------------------------------------

void registerInterfacesFunctionInterfacesBindings() {
  // crest::FunctionOpInterface::getInterfaceID - TypeID* for the dispatcher.
  Sregister_symbol(
      "crest::FunctionOpInterface::getInterfaceID", (void*)+[]() -> uint64_t {
        static mlir::TypeID id = mlir::FunctionOpInterface::getInterfaceID();
        return reinterpret_cast<uint64_t>(&id);
      });

  // Register the concept creator so crest::registerInterfaceForOperation
  // (in Dialect.cpp) can dispatch to it by TypeID.
  crest::registerConceptCreator(
      mlir::FunctionOpInterface::getInterfaceID(),
      &crest::SupportedInterfaces<mlir::FunctionOpInterface>::CreateConcept);

  // Trigger initialisation of the default concept — registration under "."
  // happens inside getOrCreateDefaultConcept() on first call.
  getOrCreateDefaultConcept();

  // mlir::function_interface_impl::parseFunctionOp - parses a function-like op.
  // The FuncTypeBuilder builds a FunctionType from arg/result types.
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

  // mlir::function_interface_impl::printFunctionOp - pretty-prints the op.
  // Requires that the op has been looked up as a FunctionOpInterface.
  Sregister_symbol(
      "mlir::function_interface_impl::printFunctionOp",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        mlir::FunctionOpInterface fn(op, getOrCreateDefaultConcept());
        auto* ctx = op->getContext();
        mlir::function_interface_impl::printFunctionOp(
            *p, fn, /*isVariadic=*/false, "function_type",
            mlir::StringAttr::get(ctx, "arg_attrs"),
            mlir::StringAttr::get(ctx, "res_attrs"));
      });

  // crest::FunctionOpInterface::default::* - expose each default lambda from
  // getOrCreateDefaultConcept() so the Scheme mlir::FunctionOpInterface
  // procedure can call the C++ defaults directly.
  Sregister_symbol(
      "crest::FunctionOpInterface::default::getFunctionType",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return reinterpret_cast<uint64_t>(getOrCreateDefaultConcept()
                                              ->getFunctionType(nullptr, op)
                                              .getAsOpaquePointer());
      });

  Sregister_symbol(
      "crest::FunctionOpInterface::default::setFunctionTypeAttr",
      (void*)+[](uint64_t op_ptr, uint64_t attr_ptr) -> void {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        mlir::TypeAttr t =
            mlir::cast<mlir::TypeAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
        getOrCreateDefaultConcept()->setFunctionTypeAttr(nullptr, op, t);
      });

  Sregister_symbol(
      "crest::FunctionOpInterface::default::verifyBody",
      (void*)+[](uint64_t op_ptr) -> int {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return mlir::succeeded(
                   getOrCreateDefaultConcept()->verifyBody(nullptr, op))
                   ? 1
                   : 0;
      });

  Sregister_symbol(
      "crest::FunctionOpInterface::default::verifyType",
      (void*)+[](uint64_t op_ptr) -> int {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return mlir::succeeded(
                   getOrCreateDefaultConcept()->verifyType(nullptr, op))
                   ? 1
                   : 0;
      });
}

} // namespace crest

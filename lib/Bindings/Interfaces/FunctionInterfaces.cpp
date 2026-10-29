/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/FunctionInterfaces.h

#include "FunctionInterfaces.h"
#include "../../Crest/Interface.h"
#include "../IR/SymbolInterfaces.h"
#include "../Support/LockedSchemeObject.h"
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
#include <memory>

// ---------------------------------------------------------------------------
// FunctionConceptData — file-local; no template, no header.
//
// Inherits from mlir::FunctionOpInterface::Concept so FunctionConceptData*
// is implicitly convertible to Concept*, and static_cast downcasts are valid.
// Stores the
// per-method locked Scheme lambdas.  Default-constructed fields hold Sfalse.
// ---------------------------------------------------------------------------
namespace {
struct FunctionConceptData : public mlir::FunctionOpInterface::Concept {
  crest::LockedSchemeObject get_function_type;
  crest::LockedSchemeObject set_function_type_attr;
  crest::LockedSchemeObject clone_type_with;
  crest::LockedSchemeObject verify_body;
  crest::LockedSchemeObject verify_type;

  FunctionConceptData()
      : mlir::FunctionOpInterface::Concept{
            [](const mlir::FunctionOpInterface::Concept*,
               mlir::Operation* op) -> mlir::Type {
              return mlir::cast<mlir::TypeAttr>(op->getAttr("function_type"))
                  .getValue();
            },
            [](const mlir::FunctionOpInterface::Concept*, mlir::Operation* op,
               mlir::TypeAttr t) { op->setAttr("function_type", t); },
            [](const mlir::FunctionOpInterface::Concept*, mlir::Operation* op,
               mlir::TypeRange inputs, mlir::TypeRange results) -> mlir::Type {
              return mlir::FunctionType::get(op->getContext(), inputs, results);
            },
            [](const mlir::FunctionOpInterface::Concept*, mlir::Operation*)
                -> llvm::LogicalResult { return mlir::success(); },
            [](const mlir::FunctionOpInterface::Concept*, mlir::Operation*)
                -> llvm::LogicalResult { return mlir::success(); },
            crest::SupportedInterfaces<
                mlir::SymbolOpInterface>::getOrCreateDefaultConcept(),
            crest::SupportedInterfaces<mlir::ArgAndResultAttrsOpInterface>::
                getOrCreateDefaultConcept(),
            crest::SupportedInterfaces<
                mlir::CallableOpInterface>::getOrCreateDefaultConcept()} {
    assert(get_function_type.get() == Sfalse);
    assert(set_function_type_attr.get() == Sfalse);
    assert(clone_type_with.get() == Sfalse);
    assert(verify_body.get() == Sfalse);
    assert(verify_type.get() == Sfalse);
  }

  FunctionConceptData(const FunctionConceptData& other)
      : mlir::FunctionOpInterface::Concept(other) {
    assert(other.get_function_type.get() == Sfalse);
    assert(other.set_function_type_attr.get() == Sfalse);
    assert(other.clone_type_with.get() == Sfalse);
    assert(other.verify_body.get() == Sfalse);
    assert(other.verify_type.get() == Sfalse);
  }
};
} // anonymous namespace

namespace crest {

// ---------------------------------------------------------------------------
// SupportedInterfaces<FunctionOpInterface>::getOrCreateDefaultConcept
// ---------------------------------------------------------------------------
template <>
mlir::FunctionOpInterface::Concept* crest::SupportedInterfaces<
    mlir::FunctionOpInterface>::getOrCreateDefaultConcept() {
  static mlir::FunctionOpInterface::Concept* ptr = [] {
    return getOrCreateDefaultConcept(std::make_unique<FunctionConceptData>());
  }();
  return ptr;
}
template <>
std::shared_ptr<void>
crest::SupportedInterfaces<mlir::FunctionOpInterface>::CloneConcept(
    const mlir::FunctionOpInterface::Concept* from) {
  const auto* src = static_cast<const FunctionConceptData*>(from);
  auto new_data = std::make_unique<FunctionConceptData>(*src);
  return std::shared_ptr<void>(new_data.release(), [](void* p) {
    delete static_cast<FunctionConceptData*>(p);
  });
}
// CreateConcept - copies the default concept, overrides named slots for each
// method the dispatcher provides, then registers via RegisterInterfaceForOp.
template <>
mlir::FunctionOpInterface::Concept*
crest::SupportedInterfaces<mlir::FunctionOpInterface>::CreateConcept(
    ptr dispatcher) {
  // Lock dispatcher to pin it in memory: Sstring_to_symbol() and scheme_call()
  // can trigger GC which would move the dispatcher closure, leaving the C local
  // variable stale. Locking prevents GC from relocating it.
  crest::LockedSchemeObject locked_dispatcher(dispatcher);
  using Concept = mlir::FunctionOpInterface::Concept;
  std::string op_name = Conversion<ptr, std::string>{}(
      scheme_call(dispatcher, Sstring_to_symbol("operation_name")));

  // Each scheme_call can trigger GC. Lock every returned ptr immediately so
  // subsequent scheme_calls cannot invalidate earlier values.
  crest::LockedSchemeObject getFunctionType(
      scheme_call(dispatcher, Sstring_to_symbol("getFunctionType")));
  crest::LockedSchemeObject setFunctionTypeAttr(
      scheme_call(dispatcher, Sstring_to_symbol("setFunctionTypeAttr")));
  crest::LockedSchemeObject cloneTypeWith(
      scheme_call(dispatcher, Sstring_to_symbol("cloneTypeWith")));
  crest::LockedSchemeObject verifyBody(
      scheme_call(dispatcher, Sstring_to_symbol("verifyBody")));
  crest::LockedSchemeObject verifyType(
      scheme_call(dispatcher, Sstring_to_symbol("verifyType")));

  // Copy default; override only the provided slots by field name.
  auto data = std::make_unique<FunctionConceptData>();

  // Set base interface pointers: get-or-create per-op concepts from the
  // registry.
  data->implSymbolOpInterface =
      getOrCreateConcept<mlir::SymbolOpInterface>(op_name);
  data->implArgAndResultAttrsOpInterface =
      getOrCreateConcept<mlir::ArgAndResultAttrsOpInterface>(op_name);
  data->implCallableOpInterface =
      getOrCreateConcept<mlir::CallableOpInterface>(op_name);

  if (getFunctionType.get() != Sfalse) {
    data->get_function_type = crest::LockedSchemeObject(getFunctionType.get());
    data->getFunctionType =
        +[](const Concept* self, mlir::Operation* op) -> mlir::Type {
      const auto* d = static_cast<const FunctionConceptData*>(self);
      ptr r = scheme_call(d->get_function_type.get(),
                          reinterpret_cast<uint64_t>(op));
      return mlir::Type::getFromOpaquePointer(
          reinterpret_cast<const void*>(Sunsigned64_value(r)));
    };
  }
  if (setFunctionTypeAttr.get() != Sfalse) {
    data->set_function_type_attr =
        crest::LockedSchemeObject(setFunctionTypeAttr.get());
    data->setFunctionTypeAttr =
        +[](const Concept* self, mlir::Operation* op, mlir::TypeAttr t) {
          const auto* d = static_cast<const FunctionConceptData*>(self);
          scheme_call(d->set_function_type_attr.get(),
                      reinterpret_cast<uint64_t>(op),
                      reinterpret_cast<uint64_t>(t.getAsOpaquePointer()));
        };
  }
  if (cloneTypeWith.get() != Sfalse) {
    data->clone_type_with = crest::LockedSchemeObject(cloneTypeWith.get());
    data->cloneTypeWith =
        +[](const Concept* self, mlir::Operation* op, mlir::TypeRange inputs,
            mlir::TypeRange results) -> mlir::Type {
      const auto* d = static_cast<const FunctionConceptData*>(self);
      ptr r = scheme_call(d->clone_type_with.get(),
                          reinterpret_cast<uint64_t>(op), inputs, results);
      return mlir::Type::getFromOpaquePointer(
          reinterpret_cast<const void*>(Sunsigned64_value(r)));
    };
  }
  if (verifyBody.get() != Sfalse) {
    data->verify_body = crest::LockedSchemeObject(verifyBody.get());
    data->verifyBody =
        +[](const Concept* self, mlir::Operation* op) -> llvm::LogicalResult {
      const auto* d = static_cast<const FunctionConceptData*>(self);
      ptr r = scheme_call(d->verify_body.get(), reinterpret_cast<uint64_t>(op));
      return r == Strue ? mlir::success() : mlir::failure();
    };
  }
  if (verifyType.get() != Sfalse) {
    data->verify_type = crest::LockedSchemeObject(verifyType.get());
    data->verifyType =
        +[](const Concept* self, mlir::Operation* op) -> llvm::LogicalResult {
      const auto* d = static_cast<const FunctionConceptData*>(self);
      ptr r = scheme_call(d->verify_type.get(), reinterpret_cast<uint64_t>(op));
      return r == Strue ? mlir::success() : mlir::failure();
    };
  }
  if (!data->getFunctionType) {
    scheme_error("FunctionOpInterface::CreateConcept", op_name,
                 ": getFunctionType is null");
  }
  if (!data->setFunctionTypeAttr) {
    scheme_error("FunctionOpInterface::CreateConcept", op_name,
                 ": setFunctionTypeAttr is null");
  }
  // cloneTypeWith, verifyBody, verifyType are optional: if #f, the default
  // concept implementation (from getOrCreateDefaultConcept) is kept.
  auto* raw = data.get();
  crest::RegisterInterfaceForOp(
      mlir::FunctionOpInterface::getInterfaceID(), op_name,
      std::shared_ptr<void>(data.release(), [](void* p) {
        delete static_cast<FunctionConceptData*>(p);
      }));
  return raw;
}

// Sregister_symbol bindings
// ---------------------------------------------------------------------------

void registerInterfacesFunctionInterfacesBindings() {
  Sregister_symbol(
      "mlir::FunctionOpInterface", (void*)+[](ptr dispatcher) {
        crest::SupportedInterfaces<mlir::FunctionOpInterface>::CreateConcept(
            dispatcher);
      });

  // Trigger initialisation of the default concept — registration under "."
  // happens inside
  // SupportedInterfaces<mlir::FunctionOpInterface>::getOrCreateDefaultConcept()
  // on first call.
  SupportedInterfaces<mlir::FunctionOpInterface>::getOrCreateDefaultConcept();

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
        mlir::FunctionOpInterface fn(
            op, SupportedInterfaces<
                    mlir::FunctionOpInterface>::getOrCreateDefaultConcept());
        auto* ctx = op->getContext();
        mlir::function_interface_impl::printFunctionOp(
            *p, fn, /*isVariadic=*/false, "function_type",
            mlir::StringAttr::get(ctx, "arg_attrs"),
            mlir::StringAttr::get(ctx, "res_attrs"));
      });

  // ---- FunctionOpInterface method bindings --------------------------------
  // Each binding looks up the concept for the op, errors if not found, then
  // calls the appropriate concept function pointer.

  Sregister_symbol(
      "mlir::FunctionOpInterface::getFunctionType",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto name_str = op->getName().getStringRef().str();
        auto* c = static_cast<mlir::FunctionOpInterface::Concept*>(
            LookupInterfaceForOp(mlir::FunctionOpInterface::getInterfaceID(),
                                 name_str));
        auto fn = mlir::dyn_cast<mlir::FunctionOpInterface>(op);
        llvm::errs() << "fn=" << (void*)fn << "  c=" << (void*)c << "\n";
        if (!c) {
          scheme_error(
              "mlir::FunctionOpInterface::getFunctionType",
              "op does not implement FunctionOpInterface:", name_str.c_str());
        }
        return reinterpret_cast<uint64_t>(
            c->getFunctionType(c, op).getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::setFunctionTypeAttr",
      (void*)+[](uint64_t op_ptr, uint64_t attr_ptr) -> void {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = static_cast<mlir::FunctionOpInterface::Concept*>(
            LookupInterfaceForOp(mlir::FunctionOpInterface::getInterfaceID(),
                                 op->getName().getStringRef().str()));
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
        auto* c = static_cast<mlir::FunctionOpInterface::Concept*>(
            LookupInterfaceForOp(mlir::FunctionOpInterface::getInterfaceID(),
                                 op->getName().getStringRef().str()));
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
        auto* c = static_cast<mlir::FunctionOpInterface::Concept*>(
            LookupInterfaceForOp(mlir::FunctionOpInterface::getInterfaceID(),
                                 op->getName().getStringRef().str()));
        if (!c) {
          scheme_error("mlir::FunctionOpInterface::verifyType",
                       "op does not implement FunctionOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        return mlir::succeeded(c->verifyType(c, op)) ? 1 : 0;
      });
}

} // namespace crest

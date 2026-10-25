/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/FunctionInterfaces.h

#include "FunctionInterfaces.h"
#include "../../Crest/Interface.h"
#include "../Support/SchemeWrapper.h"
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
// Static Concept structs for the four interfaces FunctionOpInterface depends
// on. These are populated with the minimal function pointers required by
// mlir::function_interface_impl::printFunctionOp, with stub implementations
// for methods that are not called during printing.
//
// The getRegisteredInterfaceForOp path returns raw Concept* pointers directly;
// initializeInterfaceConcept is NOT called, so the base-interface asserts in
// FunctionOpInterface::Concept do not fire. We set the base pointers ourselves.
// ---------------------------------------------------------------------------

// ── ArgAndResultAttrsOpInterface ──────────────────────────────────────────
// printFunctionOp calls getArgAttrsAttr/getResAttrsAttr; returning nullptr
// is safe — it means no per-arg/result attributes are printed.
static mlir::ArgAndResultAttrsOpInterface::Concept g_arg_result_attrs_concept{
    // getArgAttrsAttr
    [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
       mlir::Operation*) -> mlir::ArrayAttr { return nullptr; },
    // getResAttrsAttr
    [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
       mlir::Operation*) -> mlir::ArrayAttr { return nullptr; },
    // setArgAttrsAttr
    [](const mlir::ArgAndResultAttrsOpInterface::Concept*, mlir::Operation*,
       mlir::ArrayAttr) {},
    // setResAttrsAttr
    [](const mlir::ArgAndResultAttrsOpInterface::Concept*, mlir::Operation*,
       mlir::ArrayAttr) {},
    // removeArgAttrsAttr
    [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
       mlir::Operation*) -> mlir::Attribute { return nullptr; },
    // removeResAttrsAttr
    [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
       mlir::Operation*) -> mlir::Attribute { return nullptr; },
};

// ── CallableOpInterface ───────────────────────────────────────────────────
// printFunctionOp does not call CallableOpInterface directly but
// FunctionOpInterface needs the base pointer non-null if
// initializeInterfaceConcept were called (it isn't via
// getRegisteredInterfaceForOp).  We set it anyway for safety.
static mlir::CallableOpInterface::Concept g_callable_concept{
    // getCallableRegion: return the function body region
    [](const mlir::CallableOpInterface::Concept*,
       mlir::Operation* op) -> mlir::Region* { return &op->getRegion(0); },
    // getArgumentTypes: from function_type attr
    [](const mlir::CallableOpInterface::Concept*,
       mlir::Operation* op) -> llvm::ArrayRef<mlir::Type> {
      auto ft = mlir::cast<mlir::FunctionType>(
          mlir::cast<mlir::TypeAttr>(op->getAttr("function_type")).getValue());
      return ft.getInputs();
    },
    // getResultTypes: from function_type attr
    [](const mlir::CallableOpInterface::Concept*,
       mlir::Operation* op) -> llvm::ArrayRef<mlir::Type> {
      auto ft = mlir::cast<mlir::FunctionType>(
          mlir::cast<mlir::TypeAttr>(op->getAttr("function_type")).getValue());
      return ft.getResults();
    },
};

// ── SymbolOpInterface ─────────────────────────────────────────────────────
// printFunctionOp calls op.getName() which dispatches to getNameAttr.
// Other methods are stubs.
static mlir::SymbolOpInterface::Concept g_symbol_concept{
    // getNameAttr
    [](const mlir::SymbolOpInterface::Concept*,
       mlir::Operation* op) -> mlir::StringAttr {
      return mlir::cast<mlir::StringAttr>(op->getAttr("sym_name"));
    },
    // setName
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation* op,
       mlir::StringAttr name) { op->setAttr("sym_name", name); },
    // getVisibility
    [](const mlir::SymbolOpInterface::Concept*,
       mlir::Operation*) -> mlir::SymbolTable::Visibility {
      return mlir::SymbolTable::Visibility::Public;
    },
    // isNested
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) -> bool {
      return false;
    },
    // isPrivate
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) -> bool {
      return false;
    },
    // isPublic
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) -> bool {
      return true;
    },
    // setVisibility
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*,
       mlir::SymbolTable::Visibility) {},
    // setNested / setPrivate / setPublic
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) {},
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) {},
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) {},
    // getSymbolUses
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*,
       mlir::Operation*) -> std::optional<mlir::SymbolTable::UseRange> {
      return std::nullopt;
    },
    // symbolKnownUseEmpty
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*,
       mlir::Operation*) -> bool { return true; },
    // replaceAllSymbolUses
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*,
       mlir::StringAttr,
       mlir::Operation*) -> llvm::LogicalResult { return mlir::failure(); },
    // isOptionalSymbol
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) -> bool {
      return false;
    },
    // canDiscardOnUseEmpty
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) -> bool {
      return false;
    },
    // isDeclaration
    [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) -> bool {
      return false;
    },
};

// ── FunctionOpInterface ───────────────────────────────────────────────────
static mlir::FunctionOpInterface::Concept g_function_concept{
    // getFunctionType: read from "function_type" TypeAttr
    [](const mlir::FunctionOpInterface::Concept*,
       mlir::Operation* op) -> mlir::Type {
      return mlir::cast<mlir::TypeAttr>(op->getAttr("function_type"))
          .getValue();
    },
    // setFunctionTypeAttr
    [](const mlir::FunctionOpInterface::Concept*, mlir::Operation* op,
       mlir::TypeAttr t) { op->setAttr("function_type", t); },
    // cloneTypeWith — stub (not called by printFunctionOp)
    [](const mlir::FunctionOpInterface::Concept*, mlir::Operation* op,
       mlir::TypeRange inputs, mlir::TypeRange results) -> mlir::Type {
      return mlir::FunctionType::get(op->getContext(), inputs, results);
    },
    // verifyBody
    [](const mlir::FunctionOpInterface::Concept*,
       mlir::Operation*) -> llvm::LogicalResult { return mlir::success(); },
    // verifyType
    [](const mlir::FunctionOpInterface::Concept*,
       mlir::Operation*) -> llvm::LogicalResult { return mlir::success(); },
    // base interface pointers (set directly since initializeInterfaceConcept
    // is not called via getRegisteredInterfaceForOp)
    &g_symbol_concept,
    &g_arg_result_attrs_concept,
    &g_callable_concept,
};

// ---------------------------------------------------------------------------
// FunctionConceptData — file-local; no template, no header.
//
// Stores the concept struct (byte 0, layout trick: self == data) alongside
// per-method locked Scheme lambdas.  Sfalse means "use C++ default."
// ---------------------------------------------------------------------------
namespace {
struct FunctionConceptData {
  mlir::FunctionOpInterface::Concept concept; // MUST be first — self == data
  ptr get_function_type;
  ptr set_function_type_attr;
  // cloneTypeWith: TypeRange is marshalled to a Scheme list of uptr values
  // (one per mlir::Type opaque pointer) before calling the Scheme lambda.
  ptr clone_type_with;
  ptr verify_body;
  ptr verify_type;
};
} // anonymous namespace

// ---------------------------------------------------------------------------
// SupportedInterfaces<FunctionOpInterface> specialisations.
// ---------------------------------------------------------------------------

// CreateDefaultConcept — returns the CREST default concept by value.
// No allocation, no registration.
template <>
mlir::FunctionOpInterface::Concept
crest::SupportedInterfaces<mlir::FunctionOpInterface>::CreateDefaultConcept() {
  return g_function_concept;
}

// Static override lambdas — non-capturing; use self == FunctionConceptData*
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

// CreateConcept — copies the default concept, overrides named slots for each
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

  auto no_del = [](void*) {};
  if (has_override) {
    // Copy default; override only the provided slots by field name.
    auto* data = new FunctionConceptData{
        CreateDefaultConcept(), Sfalse, Sfalse, Sfalse, Sfalse, Sfalse};
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
  } else {
    crest::RegisterInterfaceForOp(
        mlir::FunctionOpInterface::getInterfaceID(), op_name,
        std::shared_ptr<void>(&g_function_concept, no_del));
  }
  // Sub-interfaces always use their static defaults.
  crest::RegisterInterfaceForOp(
      mlir::SymbolOpInterface::getInterfaceID(), op_name,
      std::shared_ptr<void>(&g_symbol_concept, no_del));
  crest::RegisterInterfaceForOp(
      mlir::ArgAndResultAttrsOpInterface::getInterfaceID(), op_name,
      std::shared_ptr<void>(&g_arg_result_attrs_concept, no_del));
  crest::RegisterInterfaceForOp(
      mlir::CallableOpInterface::getInterfaceID(), op_name,
      std::shared_ptr<void>(&g_callable_concept, no_del));
}

// Sregister_symbol bindings
// ---------------------------------------------------------------------------

void registerInterfacesFunctionInterfacesBindings() {
  // crest::FunctionOpInterface::getInterfaceID — TypeID* for the dispatcher.
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

  // mlir::function_interface_impl::parseFunctionOp — parses a function-like op.
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

  // mlir::function_interface_impl::printFunctionOp — pretty-prints the op.
  // Requires that the op has been looked up as a FunctionOpInterface.
  Sregister_symbol(
      "mlir::function_interface_impl::printFunctionOp",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        mlir::FunctionOpInterface fn(op, &g_function_concept);
        auto* ctx = op->getContext();
        mlir::function_interface_impl::printFunctionOp(
            *p, fn, /*isVariadic=*/false, "function_type",
            mlir::StringAttr::get(ctx, "arg_attrs"),
            mlir::StringAttr::get(ctx, "res_attrs"));
      });

  // crest::FunctionOpInterface::default::* — expose each default lambda from
  // g_function_concept so the Scheme mlir::FunctionOpInterface procedure can
  // call the C++ defaults without going through g_scheme_fop_concept.
  Sregister_symbol(
      "crest::FunctionOpInterface::default::getFunctionType",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return reinterpret_cast<uint64_t>(
            g_function_concept.getFunctionType(nullptr, op)
                .getAsOpaquePointer());
      });

  Sregister_symbol(
      "crest::FunctionOpInterface::default::setFunctionTypeAttr",
      (void*)+[](uint64_t op_ptr, uint64_t attr_ptr) -> void {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        mlir::TypeAttr t =
            mlir::cast<mlir::TypeAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
        g_function_concept.setFunctionTypeAttr(nullptr, op, t);
      });

  Sregister_symbol(
      "crest::FunctionOpInterface::default::verifyBody",
      (void*)+[](uint64_t op_ptr) -> int {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return mlir::succeeded(g_function_concept.verifyBody(nullptr, op)) ? 1
                                                                           : 0;
      });

  Sregister_symbol(
      "crest::FunctionOpInterface::default::verifyType",
      (void*)+[](uint64_t op_ptr) -> int {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return mlir::succeeded(g_function_concept.verifyType(nullptr, op)) ? 1
                                                                           : 0;
      });
}

} // namespace crest

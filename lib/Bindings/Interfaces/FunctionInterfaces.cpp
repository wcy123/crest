/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/FunctionInterfaces.h

#include "FunctionInterfaces.h"
#include "../../Crest/Interface.h"
#include "../Support/SchemeConceptHolder.h"
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
// DefaultConcept specialisations — one per interface covered by
// FunctionOpInterface.  Each returns a pointer to the static default concept.
// ---------------------------------------------------------------------------

template <>
mlir::FunctionOpInterface::Concept*
crest::DefaultConcept<mlir::FunctionOpInterface>::get() {
  return &g_function_concept;
}
template <>
mlir::SymbolOpInterface::Concept*
crest::DefaultConcept<mlir::SymbolOpInterface>::get() {
  return &g_symbol_concept;
}
template <>
mlir::ArgAndResultAttrsOpInterface::Concept*
crest::DefaultConcept<mlir::ArgAndResultAttrsOpInterface>::get() {
  return &g_arg_result_attrs_concept;
}
template <>
mlir::CallableOpInterface::Concept*
crest::DefaultConcept<mlir::CallableOpInterface>::get() {
  return &g_callable_concept;
}

// ---------------------------------------------------------------------------
// SupportedInterfacesRegistry for FunctionOpInterface and its sub-interfaces.
// ---------------------------------------------------------------------------
static crest::SupportedInterfacesRegistry<
    mlir::FunctionOpInterface, mlir::SymbolOpInterface,
    mlir::ArgAndResultAttrsOpInterface, mlir::CallableOpInterface>
    g_function_op_interface_registry;

// ---------------------------------------------------------------------------
// SchemeConceptHolder<FunctionOpInterface> constructor specialisation.
//
// Initialises the concept with per-op Scheme dispatch lambdas.  Each lambda
// casts `self` back to SchemeConceptHolder* to reach scheme_proc — no
// hash-table lookup; the concept pointer IS the per-op identity.
//
// cloneTypeWith is left as a C++ default because TypeRange cannot cross the
// FFI boundary.  The default_concept parameter is unused here (all needed
// values are either from Scheme or from the file-scope static concepts).
// ---------------------------------------------------------------------------
template <>
crest::SchemeConceptHolder<mlir::FunctionOpInterface>::SchemeConceptHolder(
    SValue proc, const Concept& /*default_concept*/)
    : concept {
          // getFunctionType: (proc 'getFunctionType op) → type-ptr
          [](const mlir::FunctionOpInterface::Concept* self,
             mlir::Operation* op) -> mlir::Type {
            const auto* h = reinterpret_cast<const SchemeConceptHolder*>(self);
            SValue r = scheme_call(h->scheme_proc,
                                   Sstring_to_symbol("getFunctionType"),
                                   reinterpret_cast<uint64_t>(op));
            return mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(Sunsigned64_value(r)));
          },
          // setFunctionTypeAttr: (proc 'setFunctionTypeAttr op attr)
          [](const mlir::FunctionOpInterface::Concept* self,
             mlir::Operation* op, mlir::TypeAttr t) {
            const auto* h = reinterpret_cast<const SchemeConceptHolder*>(self);
            scheme_call(h->scheme_proc,
                        Sstring_to_symbol("setFunctionTypeAttr"),
                        reinterpret_cast<uint64_t>(op),
                        reinterpret_cast<uint64_t>(t.getAsOpaquePointer()));
          },
          // cloneTypeWith — TypeRange cannot cross FFI boundary; C++ default
          [](const mlir::FunctionOpInterface::Concept*, mlir::Operation* op,
             mlir::TypeRange inputs, mlir::TypeRange results) -> mlir::Type {
            return mlir::FunctionType::get(op->getContext(), inputs, results);
          },
          // verifyBody: (proc 'verifyBody op) → bool
          [](const mlir::FunctionOpInterface::Concept* self,
             mlir::Operation* op) -> llvm::LogicalResult {
            const auto* h = reinterpret_cast<const SchemeConceptHolder*>(self);
            SValue r =
                scheme_call(h->scheme_proc, Sstring_to_symbol("verifyBody"),
                            reinterpret_cast<uint64_t>(op));
            return r == Strue ? mlir::success() : mlir::failure();
          },
          // verifyType: (proc 'verifyType op) → bool
          [](const mlir::FunctionOpInterface::Concept* self,
             mlir::Operation* op) -> llvm::LogicalResult {
            const auto* h = reinterpret_cast<const SchemeConceptHolder*>(self);
            SValue r =
                scheme_call(h->scheme_proc, Sstring_to_symbol("verifyType"),
                            reinterpret_cast<uint64_t>(op));
            return r == Strue ? mlir::success() : mlir::failure();
          },
          // base interface pointers — shared static defaults
          &g_symbol_concept,
          &g_arg_result_attrs_concept,
          &g_callable_concept,
      },
      scheme_proc{proc} {}

// ---------------------------------------------------------------------------
// Sregister_symbol bindings
// ---------------------------------------------------------------------------

void registerInterfacesFunctionInterfacesBindings() {
  // crest::FunctionOpInterface::registerConcept — register the interface
  // concept for one op.  If scheme_proc is non-zero a SchemeConceptHolder is
  // created (Scheme dispatch); otherwise the C++ default concept is used.
  // All sub-interfaces (SymbolOpInterface, etc.) are registered in the same
  // call via SupportedInterfacesRegistry::registerForOp.
  Sregister_symbol(
      "crest::FunctionOpInterface::registerConcept",
      (void*)+[](const char* op_name, uint64_t scheme_proc_val) -> void {
        if (scheme_proc_val) {
          SValue proc = static_cast<SValue>(scheme_proc_val);
          crest::SchemeConceptHolder<mlir::FunctionOpInterface>::
              getOrCreateConcept(op_name, proc,
                                 g_function_op_interface_registry);
        } else {
          g_function_op_interface_registry.registerForOp(
              op_name, mlir::FunctionOpInterface::getInterfaceID(),
              crest::DefaultConcept<mlir::FunctionOpInterface>::get());
        }
      });

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

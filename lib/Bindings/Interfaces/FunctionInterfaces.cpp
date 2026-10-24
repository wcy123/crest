/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/FunctionInterfaces.h

#include "FunctionInterfaces.h"
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
#include <string>
#include <unordered_map>

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
// Scheme-dispatch concept — used when an op declares :interfaces with method
// bodies.  Each lambda looks up a locked Scheme procedure in
// g_scheme_fop_dispatch (keyed by fully-qualified op name, e.g. "toy.func") and
// calls it via scheme_call.  Falls back to the static g_function_concept when
// no override is registered for the op.
// ---------------------------------------------------------------------------

// Map op-name → locked Scheme procedure (SValue, protected from GC).
// Populated by crest::FunctionOpInterface::setSchemeDispatch at dialect init.
static std::unordered_map<std::string, SValue> g_scheme_fop_dispatch;

static mlir::FunctionOpInterface::Concept g_scheme_fop_concept{
    // getFunctionType — single call: (proc 'getFunctionType op)
    [](const mlir::FunctionOpInterface::Concept*,
       mlir::Operation* op) -> mlir::Type {
      auto it = g_scheme_fop_dispatch.find(op->getName().getStringRef().str());
      if (it == g_scheme_fop_dispatch.end()) {
        return g_function_concept.getFunctionType(nullptr, op);
      }
      SValue r = scheme_call(it->second, Sstring_to_symbol("getFunctionType"),
                             reinterpret_cast<uint64_t>(op));
      return mlir::Type::getFromOpaquePointer(
          reinterpret_cast<const void*>(Sunsigned64_value(r)));
    },
    // setFunctionTypeAttr — single call: (proc 'setFunctionTypeAttr op attr)
    [](const mlir::FunctionOpInterface::Concept*, mlir::Operation* op,
       mlir::TypeAttr t) {
      auto it = g_scheme_fop_dispatch.find(op->getName().getStringRef().str());
      if (it == g_scheme_fop_dispatch.end()) {
        g_function_concept.setFunctionTypeAttr(nullptr, op, t);
        return;
      }
      scheme_call(it->second, Sstring_to_symbol("setFunctionTypeAttr"),
                  reinterpret_cast<uint64_t>(op),
                  reinterpret_cast<uint64_t>(t.getAsOpaquePointer()));
    },
    // cloneTypeWith — TypeRange cannot be trivially passed to Scheme; fall back
    [](const mlir::FunctionOpInterface::Concept*, mlir::Operation* op,
       mlir::TypeRange inputs, mlir::TypeRange results) -> mlir::Type {
      return mlir::FunctionType::get(op->getContext(), inputs, results);
    },
    // verifyBody — single call: (proc 'verifyBody op)
    [](const mlir::FunctionOpInterface::Concept*,
       mlir::Operation* op) -> llvm::LogicalResult {
      auto it = g_scheme_fop_dispatch.find(op->getName().getStringRef().str());
      if (it == g_scheme_fop_dispatch.end()) {
        return mlir::success();
      }
      SValue r = scheme_call(it->second, Sstring_to_symbol("verifyBody"),
                             reinterpret_cast<uint64_t>(op));
      return r == Strue ? mlir::success() : mlir::failure();
    },
    // verifyType — single call: (proc 'verifyType op)
    [](const mlir::FunctionOpInterface::Concept*,
       mlir::Operation* op) -> llvm::LogicalResult {
      auto it = g_scheme_fop_dispatch.find(op->getName().getStringRef().str());
      if (it == g_scheme_fop_dispatch.end()) {
        return mlir::success();
      }
      SValue r = scheme_call(it->second, Sstring_to_symbol("verifyType"),
                             reinterpret_cast<uint64_t>(op));
      return r == Strue ? mlir::success() : mlir::failure();
    },
    // base interface pointers — shared with g_function_concept
    &g_symbol_concept,
    &g_arg_result_attrs_concept,
    &g_callable_concept,
};

// ---------------------------------------------------------------------------
// Sregister_symbol bindings
// ---------------------------------------------------------------------------

void registerInterfacesFunctionInterfacesBindings() {
  // crest::FunctionOpInterface::getInterfaceID — TypeID* for comparison in
  // Scheme.
  Sregister_symbol(
      "crest::FunctionOpInterface::getInterfaceID", (void*)+[]() -> uint64_t {
        static mlir::TypeID id = mlir::FunctionOpInterface::getInterfaceID();
        return reinterpret_cast<uint64_t>(&id);
      });

  // crest::SymbolOpInterface::getInterfaceID
  Sregister_symbol(
      "crest::SymbolOpInterface::getInterfaceID", (void*)+[]() -> uint64_t {
        static mlir::TypeID id = mlir::SymbolOpInterface::getInterfaceID();
        return reinterpret_cast<uint64_t>(&id);
      });

  // crest::ArgAndResultAttrsOpInterface::getInterfaceID
  Sregister_symbol(
      "crest::ArgAndResultAttrsOpInterface::getInterfaceID",
      (void*)+[]() -> uint64_t {
        static mlir::TypeID id =
            mlir::ArgAndResultAttrsOpInterface::getInterfaceID();
        return reinterpret_cast<uint64_t>(&id);
      });

  // crest::CallableOpInterface::getInterfaceID
  Sregister_symbol(
      "crest::CallableOpInterface::getInterfaceID", (void*)+[]() -> uint64_t {
        static mlir::TypeID id = mlir::CallableOpInterface::getInterfaceID();
        return reinterpret_cast<uint64_t>(&id);
      });

  // crest::FunctionOpInterface::getConcept — returns void* to the static
  // FunctionOpInterface::Concept for the given interface TypeID*.
  // The Scheme :get-registered-interface-for-op callback calls this with
  // the interface-id pointer and the op-name string.
  Sregister_symbol(
      "crest::FunctionOpInterface::getConcept",
      (void*)+[](uint64_t iface_id_ptr) -> uint64_t {
        auto* iface_id = reinterpret_cast<mlir::TypeID*>(iface_id_ptr);
        if (*iface_id == mlir::FunctionOpInterface::getInterfaceID()) {
          return reinterpret_cast<uint64_t>(&g_function_concept);
        }
        if (*iface_id == mlir::SymbolOpInterface::getInterfaceID()) {
          return reinterpret_cast<uint64_t>(&g_symbol_concept);
        }
        if (*iface_id == mlir::ArgAndResultAttrsOpInterface::getInterfaceID()) {
          return reinterpret_cast<uint64_t>(&g_arg_result_attrs_concept);
        }
        if (*iface_id == mlir::CallableOpInterface::getInterfaceID()) {
          return reinterpret_cast<uint64_t>(&g_callable_concept);
        }
        return 0;
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

  // crest::FunctionOpInterface::setSchemeDispatch — store a locked Scheme
  // procedure as the dispatch handler for the given op name.  Called once at
  // dialect initialisation for each op that declares method bodies.
  // op_name: char* (Chez Scheme foreign-type "string"), scheme_proc: SValue as
  // uptr.
  Sregister_symbol(
      "crest::FunctionOpInterface::setSchemeDispatch",
      (void*)+[](const char* op_name, uint64_t scheme_proc) -> void {
        SValue proc = static_cast<SValue>(scheme_proc);
        Slock_object(proc);
        g_scheme_fop_dispatch[std::string(op_name)] = proc;
      });

  // crest::FunctionOpInterface::getSchemeConceptPtr — returns
  // &g_scheme_fop_concept. Used as the concept provider for ops that have
  // Scheme method bodies.
  Sregister_symbol(
      "crest::FunctionOpInterface::getSchemeConceptPtr",
      (void*)+[](uint64_t iface_id_ptr) -> uint64_t {
        auto* iface_id = reinterpret_cast<mlir::TypeID*>(iface_id_ptr);
        if (*iface_id == mlir::FunctionOpInterface::getInterfaceID()) {
          return reinterpret_cast<uint64_t>(&g_scheme_fop_concept);
        }
        if (*iface_id == mlir::SymbolOpInterface::getInterfaceID()) {
          return reinterpret_cast<uint64_t>(&g_symbol_concept);
        }
        if (*iface_id == mlir::ArgAndResultAttrsOpInterface::getInterfaceID()) {
          return reinterpret_cast<uint64_t>(&g_arg_result_attrs_concept);
        }
        if (*iface_id == mlir::CallableOpInterface::getInterfaceID()) {
          return reinterpret_cast<uint64_t>(&g_callable_concept);
        }
        return 0;
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

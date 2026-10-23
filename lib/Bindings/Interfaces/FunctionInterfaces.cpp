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

  // mlir::OperationName::getStringRef — get the op's fully-qualified name
  // string.
  Sregister_symbol(
      "mlir::OperationName::getStringRef",
      (void*)+[](uint64_t op_name_ptr) -> const char* {
        auto* name = reinterpret_cast<mlir::OperationName*>(op_name_ptr);
        return name->getStringRef().data();
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
}

} // namespace crest

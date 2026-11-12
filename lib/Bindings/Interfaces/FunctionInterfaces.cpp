/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/FunctionInterfaces.h

#include "FunctionInterfaces.h"
#include "../../Crest/Interface.h"
#include "../IR/SymbolInterfaces.h"
#include "../Support/Result.h"
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

namespace crest {

// Each method is the callable that Scheme made for its clause, or for the MLIR
// default that the macro writes in Scheme, in its slot.
void attachFunctionOpInterface(mlir::DynamicOpDefinition& def,
                               const LockedSchemeObject& dispatcher) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  // The Concept of FunctionOpInterface looks its three bases up in the map when
  // the model is inserted. The model of CallableOpInterface has no entries
  // until the clauses of the op fill it; Op.cpp raises an error if they do not.
  ensureSymbolOpInterface(map);
  ensureArgAndResultAttrsOpInterface(map);
  ensureCallableOpInterface(map);
  insertModelOnce<mlir::FunctionOpInterface>(map);
  auto* concept_ = map.lookup<mlir::FunctionOpInterface>();
  installInterfaceEntry(concept_->getFunctionType, dispatcher,
                        "getFunctionType");
  installInterfaceEntry(concept_->setFunctionTypeAttr, dispatcher,
                        "setFunctionTypeAttr");
  installInterfaceEntry(concept_->cloneTypeWith, dispatcher, "cloneTypeWith");
  installInterfaceEntry(concept_->verifyBody, dispatcher, "verifyBody");
  installInterfaceEntry(concept_->verifyType, dispatcher, "verifyType");
}

void registerInterfacesFunctionInterfacesBindings() {
  // mlir::FunctionOpInterface::getInterfaceID () -> uptr
  //
  // The address that the TypeID of the interface wraps, which C++ turns back
  // with TypeID::getFromOpaquePointer to find how to install the interface.
  Sregister_symbol(
      "mlir::FunctionOpInterface::getInterfaceID", (void*)+[]() -> ptr {
        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::FunctionOpInterface::getInterfaceID().getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::function_interface_impl::parseFunctionOp",
      (void*)+[](uint64_t parser_ptr, uint64_t state_ptr) -> ptr {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        auto typeBuilder = [](mlir::Builder& builder,
                              llvm::ArrayRef<mlir::Type> argTypes,
                              llvm::ArrayRef<mlir::Type> resTypes,
                              mlir::function_interface_impl::VariadicFlag,
                              std::string&) -> mlir::Type {
          return builder.getFunctionType(argTypes, resTypes);
        };
        return scheme_bool(!mlir::function_interface_impl::parseFunctionOp(
            *p, state, /*allowVariadic=*/false,
            mlir::StringAttr::get(state.getContext(), "function_type"),
            typeBuilder, mlir::StringAttr::get(state.getContext(), "arg_attrs"),
            mlir::StringAttr::get(state.getContext(), "res_attrs")));
      });

  Sregister_symbol(
      "mlir::function_interface_impl::printFunctionOp",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> ptr {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::FunctionOpInterface>(op);
        if (!c) {
          return scheme_error(
              "mlir::function_interface_impl::printFunctionOp",
              llvm::Twine("op does not implement FunctionOpInterface:") + " " +
                  llvm::Twine(op->getName().getStringRef()));
        }
        mlir::FunctionOpInterface fn(op, c);
        auto* ctx = op->getContext();
        mlir::function_interface_impl::printFunctionOp(
            *p, fn, /*isVariadic=*/false, "function_type",
            mlir::StringAttr::get(ctx, "arg_attrs"),
            mlir::StringAttr::get(ctx, "res_attrs"));
        return Svoid;
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::getFunctionType",
      (void*)+[](uint64_t op_ptr) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::FunctionOpInterface>(op);
        if (!c) {
          return scheme_error(
              "mlir::FunctionOpInterface::getFunctionType",
              llvm::Twine("op does not implement FunctionOpInterface:") + " " +
                  llvm::Twine(op->getName().getStringRef()));
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            c->getFunctionType(c, op).getAsOpaquePointer()));
      });

  // mlir::FunctionOpInterface::cloneTypeWith (uptr op) (list inputs) (list
  // results) -> uptr Type: the function type of the op with these inputs and
  // results, as the Concept of the op says (the default is a FunctionType).
  Sregister_symbol(
      "mlir::FunctionOpInterface::cloneTypeWith",
      (void*)+[](uint64_t op_ptr, ptr inputs, ptr results) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::FunctionOpInterface>(op);
        if (!c) {
          return scheme_error(
              "mlir::FunctionOpInterface::cloneTypeWith",
              llvm::Twine("op does not implement FunctionOpInterface:") + " " +
                  llvm::Twine(op->getName().getStringRef()));
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
        return Sunsigned64(reinterpret_cast<uint64_t>(
            c->cloneTypeWith(c, op, inputTypes, resultTypes)
                .getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::setFunctionTypeAttr",
      (void*)+[](uint64_t op_ptr, uint64_t attr_ptr) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::FunctionOpInterface>(op);
        if (!c) {
          return scheme_error(
              "mlir::FunctionOpInterface::setFunctionTypeAttr",
              llvm::Twine("op does not implement FunctionOpInterface:") + " " +
                  llvm::Twine(op->getName().getStringRef()));
        }
        mlir::TypeAttr t =
            mlir::cast<mlir::TypeAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
        c->setFunctionTypeAttr(c, op, t);
        return Svoid;
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::verifyBody",
      (void*)+[](uint64_t op_ptr) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::FunctionOpInterface>(op);
        if (!c) {
          return scheme_error(
              "mlir::FunctionOpInterface::verifyBody",
              llvm::Twine("op does not implement FunctionOpInterface:") + " " +
                  llvm::Twine(op->getName().getStringRef()));
        }
        return scheme_bool(mlir::succeeded(c->verifyBody(c, op)));
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::verifyType",
      (void*)+[](uint64_t op_ptr) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = lookupConcept<mlir::FunctionOpInterface>(op);
        if (!c) {
          return scheme_error(
              "mlir::FunctionOpInterface::verifyType",
              llvm::Twine("op does not implement FunctionOpInterface:") + " " +
                  llvm::Twine(op->getName().getStringRef()));
        }
        return scheme_bool(mlir::succeeded(c->verifyType(c, op)));
      });
}

} // namespace crest

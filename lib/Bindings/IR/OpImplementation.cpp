/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/OpImplementation.h

#include "OpImplementation.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "llvm/ADT/SmallVector.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/IR/Region.h"
#include "mlir/IR/Value.h"

namespace crest {

void registerIROpImplementationBindings() {
  Sregister_symbol(
      "mlir::OpAsmPrinter::printString",
      (void*)+[](uint64_t printer_ptr, const char* s) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        *p << s;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printOperands",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        *p << op->getOperands();
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printOperand",
      (void*)+[](uint64_t printer_ptr, uint64_t value_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto v = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<void*>(value_ptr));
        *p << v;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printAttribute",
      (void*)+[](uint64_t printer_ptr, uint64_t attr_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<void*>(attr_ptr));
        p->printAttribute(attr);
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printType",
      (void*)+[](uint64_t printer_ptr, uint64_t type_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto t =
            mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr));
        p->printType(t);
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printOptionalAttrDict",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        p->printOptionalAttrDict(op->getAttrs());
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printOptionalAttrDictExcept",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr,
                 const char* elide) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        p->printOptionalAttrDict(op->getAttrs(),
                                 llvm::ArrayRef<llvm::StringRef>{elide});
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printFunctionalType",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        p->printFunctionalType(op);
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printResultTypes",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        llvm::interleaveComma(op->getResultTypes(), p->getStream(),
                              [&](mlir::Type t) { p->printType(t); });
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printSymbolName",
      (void*)+[](uint64_t printer_ptr, const char* name) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        p->printSymbolName(name);
      });

  Sregister_symbol(
      "mlir::StringAttr::getValue",
      (void*)+[](uint64_t attr_ptr) -> const char* {
        auto attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<void*>(attr_ptr));
        return mlir::cast<mlir::StringAttr>(attr).getValue().data();
      });

  Sregister_symbol(
      "mlir::TypeAttr::getValue", (void*)+[](uint64_t attr_ptr) -> uint64_t {
        auto attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<void*>(attr_ptr));
        return reinterpret_cast<uint64_t>(
            mlir::cast<mlir::TypeAttr>(attr).getValue().getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::FunctionType::getNumInputs",
      (void*)+[](uint64_t type_ptr) -> uint64_t {
        auto t =
            mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr));
        return mlir::cast<mlir::FunctionType>(t).getNumInputs();
      });

  Sregister_symbol(
      "mlir::FunctionType::getInput",
      (void*)+[](uint64_t type_ptr, uint64_t i) -> uint64_t {
        auto t =
            mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr));
        return reinterpret_cast<uint64_t>(
            mlir::cast<mlir::FunctionType>(t)
                .getInput(static_cast<unsigned>(i))
                .getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::FunctionType::getNumResults",
      (void*)+[](uint64_t type_ptr) -> uint64_t {
        auto t =
            mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr));
        return mlir::cast<mlir::FunctionType>(t).getNumResults();
      });

  Sregister_symbol(
      "mlir::FunctionType::getResult",
      (void*)+[](uint64_t type_ptr, uint64_t i) -> uint64_t {
        auto t =
            mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr));
        return reinterpret_cast<uint64_t>(
            mlir::cast<mlir::FunctionType>(t)
                .getResult(static_cast<unsigned>(i))
                .getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printRegion",
      (void*)+[](uint64_t printer_ptr, uint64_t region_ptr,
                 int skip_entry_block_args,
                 int print_block_terminators) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* r = reinterpret_cast<mlir::Region*>(region_ptr);
        p->printRegion(*r, static_cast<bool>(skip_entry_block_args),
                       static_cast<bool>(print_block_terminators));
      });

  // ===========================================================================
  // OpAsmParser bindings
  // ===========================================================================

  using UnresolvedOperands =
      CrestOwned<llvm::SmallVector<mlir::OpAsmParser::UnresolvedOperand, 4>>;

  Sregister_symbol(
      "mlir::OpAsmParser::parseOperandList",
      (void*)+[](uint64_t parser_ptr, int64_t required) -> uint64_t {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto* ops = new UnresolvedOperands;
        bool failed =
            required >= 0
                ? p->parseOperandList(ops->inner, static_cast<int>(required))
                      .failed()
                : p->parseOperandList(ops->inner).failed();
        if (failed) {
          delete ops;
          return 0;
        }
        return reinterpret_cast<uint64_t>(ops);
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseOperand",
      (void*)+[](uint64_t parser_ptr) -> uint64_t {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto* ops = new UnresolvedOperands;
        ops->inner.resize(1);
        if (p->parseOperand(ops->inner[0]).failed()) {
          delete ops;
          return 0;
        }
        return reinterpret_cast<uint64_t>(ops);
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseOptionalOperand",
      (void*)+[](uint64_t parser_ptr) -> uint64_t {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto* ops = new UnresolvedOperands;
        ops->inner.resize(1);
        auto result = p->parseOptionalOperand(ops->inner[0]);
        // OptionalParseResult: nullopt = not present, else success/failure
        if (!result.has_value() || result.value().failed()) {
          delete ops;
          return 0;
        }
        return reinterpret_cast<uint64_t>(ops);
      });

  Sregister_symbol(
      "mlir::OpAsmParser::resolveOperands",
      (void*)+[](uint64_t parser_ptr, uint64_t ops_handle, uint64_t type_ptr,
                 uint64_t state_ptr) -> int {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto* ops = reinterpret_cast<UnresolvedOperands*>(ops_handle);
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        return !p->resolveOperands(ops->inner, type, state.operands);
      });

  Sregister_symbol(
      "mlir::OpAsmParser::resolveOperandsFunctional",
      (void*)+[](uint64_t parser_ptr, uint64_t ops_handle,
                 uint64_t func_type_ptr, uint64_t state_ptr) -> int {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto* ops = reinterpret_cast<UnresolvedOperands*>(ops_handle);
        auto ft =
            mlir::cast<mlir::FunctionType>(mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(func_type_ptr)));
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        return !p->resolveOperands(ops->inner, ft.getInputs(), p->getNameLoc(),
                                   state.operands);
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseColonType",
      (void*)+[](uint64_t parser_ptr) -> uint64_t {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        mlir::Type t;
        if (p->parseColonType(t)) {
          return 0;
        }
        return reinterpret_cast<uint64_t>(t.getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseType",
      (void*)+[](uint64_t parser_ptr) -> uint64_t {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        mlir::Type t;
        if (p->parseType(t)) {
          return 0;
        }
        return reinterpret_cast<uint64_t>(t.getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseFunctionalType",
      (void*)+[](uint64_t parser_ptr) -> uint64_t {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        llvm::SmallVector<mlir::Type, 4> inputs, results;
        if (p->parseLParen()) {
          return 0;
        }
        if (p->parseOptionalRParen()) {
          // non-empty inputs
          mlir::Type t;
          if (p->parseType(t)) {
            return 0;
          }
          inputs.push_back(t);
          while (!p->parseOptionalComma()) {
            if (p->parseType(t)) {
              return 0;
            }
            inputs.push_back(t);
          }
          if (p->parseRParen()) {
            return 0;
          }
        }
        if (p->parseArrow()) {
          return 0;
        }
        // Result: single type or parenthesised list
        if (!p->parseLParen()) {
          if (p->parseOptionalRParen()) {
            // non-empty
            mlir::Type t;
            if (p->parseType(t)) {
              return 0;
            }
            results.push_back(t);
            while (!p->parseOptionalComma()) {
              if (p->parseType(t)) {
                return 0;
              }
              results.push_back(t);
            }
            if (p->parseRParen()) {
              return 0;
            }
          }
        } else {
          mlir::Type t;
          if (p->parseType(t)) {
            return 0;
          }
          results.push_back(t);
        }
        return reinterpret_cast<uint64_t>(
            mlir::FunctionType::get(p->getContext(), inputs, results)
                .getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseOptionalAttrDict",
      (void*)+[](uint64_t parser_ptr, uint64_t state_ptr) -> int {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        return !p->parseOptionalAttrDict(state.attributes);
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseAttribute",
      (void*)+[](uint64_t parser_ptr, uint64_t state_ptr,
                 const char* attr_name) -> uint64_t {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        mlir::Attribute attr;
        if (p->parseAttribute(attr, attr_name, state.attributes)) {
          return 0;
        }
        return reinterpret_cast<uint64_t>(attr.getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseKeyword",
      (void*)+[](uint64_t parser_ptr, const char* kw) -> int {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        return !p->parseKeyword(kw);
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseLParen", (void*)+[](uint64_t parser_ptr) -> int {
        return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseLParen();
      });
  Sregister_symbol(
      "mlir::OpAsmParser::parseRParen", (void*)+[](uint64_t parser_ptr) -> int {
        return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseRParen();
      });
  Sregister_symbol(
      "mlir::OpAsmParser::parseColon", (void*)+[](uint64_t parser_ptr) -> int {
        return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseColon();
      });
  Sregister_symbol(
      "mlir::OpAsmParser::parseComma", (void*)+[](uint64_t parser_ptr) -> int {
        return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseComma();
      });
  Sregister_symbol(
      "mlir::OpAsmParser::parseArrow", (void*)+[](uint64_t parser_ptr) -> int {
        return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseArrow();
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseSymbolName",
      (void*)+[](uint64_t parser_ptr, uint64_t state_ptr) -> ptr {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        mlir::StringAttr sym;
        if (p->parseSymbolName(sym, "callee", state.attributes)) {
          return Sstring("");
        }
        return Sstring(sym.getValue().data());
      });

  Sregister_symbol(
      "mlir::isa<FunctionType>", (void*)+[](uint64_t type_ptr) -> int {
        return mlir::isa<mlir::FunctionType>(mlir::Type::getFromOpaquePointer(
                   reinterpret_cast<void*>(type_ptr)))
                   ? 1
                   : 0;
      });

  Sregister_symbol(
      "mlir::OperationState::addType",
      (void*)+[](uint64_t state_ptr, uint64_t type_ptr) -> void {
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        state.addTypes(mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr)));
      });
}

} // namespace crest

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
  // mlir::OpAsmPrinter::printString — emit a literal string to the output
  // stream.
  Sregister_symbol(
      "mlir::OpAsmPrinter::printString",
      (void*)+[](uint64_t printer_ptr, const char* s) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        *p << s;
      });

  // mlir::OpAsmPrinter::printOperands — print all operands of op as SSA value
  // refs.
  Sregister_symbol(
      "mlir::OpAsmPrinter::printOperands",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        *p << op->getOperands();
      });

  // mlir::OpAsmPrinter::printOperand — print a single Value as an SSA ref.
  Sregister_symbol(
      "mlir::OpAsmPrinter::printOperand",
      (void*)+[](uint64_t printer_ptr, uint64_t value_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto v = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<void*>(value_ptr));
        *p << v;
      });

  // mlir::OpAsmPrinter::printAttribute — print an mlir::Attribute value.
  Sregister_symbol(
      "mlir::OpAsmPrinter::printAttribute",
      (void*)+[](uint64_t printer_ptr, uint64_t attr_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<void*>(attr_ptr));
        p->printAttribute(attr);
      });

  // mlir::OpAsmPrinter::printType — print an mlir::Type.
  Sregister_symbol(
      "mlir::OpAsmPrinter::printType",
      (void*)+[](uint64_t printer_ptr, uint64_t type_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto t =
            mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr));
        p->printType(t);
      });

  // mlir::OpAsmPrinter::printOptionalAttrDict — print attrs with no elision.
  Sregister_symbol(
      "mlir::OpAsmPrinter::printOptionalAttrDict",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        p->printOptionalAttrDict(op->getAttrs());
      });

  // mlir::OpAsmPrinter::printOptionalAttrDictExcept — elide a single named
  // attr.
  Sregister_symbol(
      "mlir::OpAsmPrinter::printOptionalAttrDictExcept",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr,
                 const char* elide) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        p->printOptionalAttrDict(op->getAttrs(),
                                 llvm::ArrayRef<llvm::StringRef>{elide});
      });

  // mlir::OpAsmPrinter::printFunctionalType — print (operand-types) ->
  // result-types.
  Sregister_symbol(
      "mlir::OpAsmPrinter::printFunctionalType",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        p->printFunctionalType(op);
      });

  // mlir::OpAsmPrinter::printResultTypes — print result types of op.
  Sregister_symbol(
      "mlir::OpAsmPrinter::printResultTypes",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        llvm::interleaveComma(op->getResultTypes(), p->getStream(),
                              [&](mlir::Type t) { p->printType(t); });
      });

  // mlir::OpAsmPrinter::printSymbolName — print @name (for callee references).
  Sregister_symbol(
      "mlir::OpAsmPrinter::printSymbolName",
      (void*)+[](uint64_t printer_ptr, const char* name) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        p->printSymbolName(name);
      });

  // mlir::StringAttr::getValue — return the string value as a C string.
  Sregister_symbol(
      "mlir::StringAttr::getValue",
      (void*)+[](uint64_t attr_ptr) -> const char* {
        auto attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<void*>(attr_ptr));
        return mlir::cast<mlir::StringAttr>(attr).getValue().data();
      });

  // mlir::TypeAttr::getValue — extract the underlying Type from a TypeAttr.
  Sregister_symbol(
      "mlir::TypeAttr::getValue", (void*)+[](uint64_t attr_ptr) -> uint64_t {
        auto attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<void*>(attr_ptr));
        return reinterpret_cast<uint64_t>(
            mlir::cast<mlir::TypeAttr>(attr).getValue().getAsOpaquePointer());
      });

  // mlir::FunctionType::getNumInputs — number of input types.
  Sregister_symbol(
      "mlir::FunctionType::getNumInputs",
      (void*)+[](uint64_t type_ptr) -> uint64_t {
        auto t =
            mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr));
        return mlir::cast<mlir::FunctionType>(t).getNumInputs();
      });

  // mlir::FunctionType::getInput — i-th input type.
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

  // mlir::FunctionType::getNumResults — number of result types.
  Sregister_symbol(
      "mlir::FunctionType::getNumResults",
      (void*)+[](uint64_t type_ptr) -> uint64_t {
        auto t =
            mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr));
        return mlir::cast<mlir::FunctionType>(t).getNumResults();
      });

  // mlir::FunctionType::getResult — i-th result type.
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

  // mlir::OpAsmPrinter::printRegion — print a region with its blocks and ops.
  // skip_entry_block_args: if #t, don't print the block label for the first
  // block.
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

  // mlir::OpAsmParser::parseOperandList — parse N operands; returns handle or
  // 0.
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

  // mlir::OpAsmParser::parseOperand — parse a single %name; returns handle or
  // 0. Emits a diagnostic on failure.
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

  // mlir::OpAsmParser::parseOptionalOperand — like parseOperand but returns 0
  // silently if no %name is present (no diagnostic emitted).
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

  // mlir::OpAsmParser::resolveOperands — resolve list against a single type.
  // Appends resolved Values to state.operands and returns success bool.
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

  // mlir::OpAsmParser::resolveOperandsFunctional — resolve against FunctionType
  // inputs.
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

  // mlir::OpAsmParser::parseColonType — parse `: type`; returns type uptr or 0.
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

  // mlir::OpAsmParser::parseType — parse a type; returns type uptr or 0.
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

  // mlir::OpAsmParser::parseFunctionalType — parse `(t1, t2) -> t3`; returns
  // FunctionType or 0.
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

  // mlir::OpAsmParser::parseOptionalAttrDict — parse `{ attr = val, ... }`
  // and merge into state.attributes. Returns success bool.
  Sregister_symbol(
      "mlir::OpAsmParser::parseOptionalAttrDict",
      (void*)+[](uint64_t parser_ptr, uint64_t state_ptr) -> int {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        return !p->parseOptionalAttrDict(state.attributes);
      });

  // mlir::OpAsmParser::parseAttribute — parse an attribute and add to state
  // under `attr-name`. Returns the parsed attr uptr or 0 on failure.
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

  // mlir::OpAsmParser::parseKeyword — parse a literal keyword; returns bool.
  Sregister_symbol(
      "mlir::OpAsmParser::parseKeyword",
      (void*)+[](uint64_t parser_ptr, const char* kw) -> int {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        return !p->parseKeyword(kw);
      });

  // mlir::OpAsmParser::parseLParen / parseRParen / parseColon / parseComma
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

  // mlir::OpAsmParser::parseSymbolName — parse `@name`; returns string or "".
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

  // mlir::isa<FunctionType>
  Sregister_symbol(
      "mlir::isa<FunctionType>", (void*)+[](uint64_t type_ptr) -> int {
        return mlir::isa<mlir::FunctionType>(mlir::Type::getFromOpaquePointer(
                   reinterpret_cast<void*>(type_ptr)))
                   ? 1
                   : 0;
      });

  // mlir::OperationState::addType — add a single result type to state.
  Sregister_symbol(
      "mlir::OperationState::addType",
      (void*)+[](uint64_t state_ptr, uint64_t type_ptr) -> void {
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        state.addTypes(mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr)));
      });
}

} // namespace crest

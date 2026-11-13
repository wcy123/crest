/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/OpImplementation.h

#include "OpImplementation.h"
#include "../Support/CrestObject.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "llvm/ADT/SmallVector.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/IR/Region.h"
#include "mlir/IR/Value.h"
#include <string>
#include <vector>

namespace crest {

namespace {

// The answer of a binding that was given a pointer that is 0. A parse or a
// print that fails answers 0, and Scheme that does not look at the answer
// passes the 0 on to the next call.
ptr nullPointer(const char* who, const char* what) {
  return scheme_error(who, llvm::Twine(what) + " pointer is null");
}

} // namespace

void registerIROpImplementationBindings() {
  // The methods of mlir::AsmPrinter, the base of OpAsmPrinter and of the
  // DialectAsmPrinter that a dialect's :print-type and :print-attribute get.
  // mlir::AsmPrinter::getStream (uptr printer) -> uptr llvm::raw_ostream*
  Sregister_symbol(
      "mlir::AsmPrinter::getStream", (void*)+[](uint64_t printer_ptr) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::AsmPrinter::getStream", "printer");
        }
        auto* p = reinterpret_cast<mlir::AsmPrinter*>(printer_ptr);
        return Sunsigned64(reinterpret_cast<uint64_t>(&p->getStream()));
      });
  Sregister_symbol(
      "mlir::AsmPrinter::printType",
      (void*)+[](uint64_t printer_ptr, uint64_t type_ptr) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::AsmPrinter::printType", "printer");
        }
        reinterpret_cast<mlir::AsmPrinter*>(printer_ptr)
            ->printType(mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
        return Svoid;
      });
  Sregister_symbol(
      "mlir::AsmPrinter::printAttribute",
      (void*)+[](uint64_t printer_ptr, uint64_t attr_ptr) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::AsmPrinter::printAttribute", "printer");
        }
        reinterpret_cast<mlir::AsmPrinter*>(printer_ptr)
            ->printAttribute(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
        return Svoid;
      });
  // The text as a keyword if it is one, else as a quoted string.
  Sregister_symbol(
      "mlir::AsmPrinter::printKeywordOrString",
      (void*)+[](uint64_t printer_ptr, const char* text) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::AsmPrinter::printKeywordOrString",
                             "printer");
        }
        reinterpret_cast<mlir::AsmPrinter*>(printer_ptr)
            ->printKeywordOrString(text);
        return Svoid;
      });
  // The text as a quoted, escaped string.
  Sregister_symbol(
      "mlir::AsmPrinter::printString",
      (void*)+[](uint64_t printer_ptr, const char* text) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::AsmPrinter::printString", "printer");
        }
        reinterpret_cast<mlir::AsmPrinter*>(printer_ptr)->printString(text);
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printString",
      (void*)+[](uint64_t printer_ptr, const char* s) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printString", "printer");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        *p << s;
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printOperands",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printOperands", "printer");
        }
        if (!op_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printOperands", "operation");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        *p << op->getOperands();
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printOperand",
      (void*)+[](uint64_t printer_ptr, uint64_t value_ptr) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printOperand", "printer");
        }
        if (!value_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printOperand", "value");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto v = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<void*>(value_ptr));
        *p << v;
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printAttributeWithoutType",
      (void*)+[](uint64_t printer_ptr, uint64_t attr_ptr) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printAttributeWithoutType",
                             "printer");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<void*>(attr_ptr));
        p->printAttributeWithoutType(attr);
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printAttribute",
      (void*)+[](uint64_t printer_ptr, uint64_t attr_ptr) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printAttribute", "printer");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<void*>(attr_ptr));
        p->printAttribute(attr);
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printType",
      (void*)+[](uint64_t printer_ptr, uint64_t type_ptr) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printType", "printer");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto t =
            mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr));
        p->printType(t);
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printOptionalAttrDict",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printOptionalAttrDict",
                             "printer");
        }
        if (!op_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printOptionalAttrDict",
                             "operation");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        p->printOptionalAttrDict(op->getAttrs());
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printOptionalAttrDictExcept",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr,
                 const char* elide) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printOptionalAttrDictExcept",
                             "printer");
        }
        if (!op_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printOptionalAttrDictExcept",
                             "operation");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        p->printOptionalAttrDict(op->getAttrs(),
                                 llvm::ArrayRef<llvm::StringRef>{elide});
        return Svoid;
      });

  // The attributes to leave out are a Scheme list of strings.
  Sregister_symbol(
      "mlir::OpAsmPrinter::printOptionalAttrDict<ArrayRef<StringRef>>",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr, ptr elided) -> ptr {
        if (!printer_ptr) {
          return nullPointer(
              "mlir::OpAsmPrinter::printOptionalAttrDict<ArrayRef<StringRef>>",
              "printer");
        }
        if (!op_ptr) {
          return nullPointer(
              "mlir::OpAsmPrinter::printOptionalAttrDict<ArrayRef<StringRef>>",
              "operation");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        std::vector<std::string> names;
        for (ptr cur = elided; Spairp(cur); cur = Scdr(cur)) {
          ptr name = Scar(cur);
          iptr length = Sstring_length(name);
          std::string& out =
              names.emplace_back(static_cast<size_t>(length), '\0');
          for (iptr i = 0; i < length; ++i) {
            out[static_cast<size_t>(i)] =
                static_cast<char>(Sstring_ref(name, i));
          }
        }
        std::vector<llvm::StringRef> refs(names.begin(), names.end());
        p->printOptionalAttrDict(op->getAttrs(), refs);
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printFunctionalType",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printFunctionalType",
                             "printer");
        }
        if (!op_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printFunctionalType",
                             "operation");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        p->printFunctionalType(op);
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printResultTypes",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printResultTypes", "printer");
        }
        if (!op_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printResultTypes",
                             "operation");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        llvm::interleaveComma(op->getResultTypes(), p->getStream(),
                              [&](mlir::Type t) { p->printType(t); });
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printSymbolName",
      (void*)+[](uint64_t printer_ptr, const char* name) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printSymbolName", "printer");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        p->printSymbolName(name);
        return Svoid;
      });

  Sregister_symbol(
      "mlir::StringAttr::getValue", (void*)+[](uint64_t attr_ptr) -> ptr {
        auto attr = mlir::dyn_cast_or_null<mlir::StringAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<void*>(attr_ptr)));
        if (!attr) {
          return scheme_error("mlir::StringAttr::getValue",
                              "the pointer is null or not a StringAttr");
        }
        return scheme_string(attr.getValue().data());
      });

  Sregister_symbol(
      "mlir::TypeAttr::getValue", (void*)+[](uint64_t attr_ptr) -> ptr {
        auto attr = mlir::dyn_cast_or_null<mlir::TypeAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<void*>(attr_ptr)));
        if (!attr) {
          return scheme_error("mlir::TypeAttr::getValue",
                              "the pointer is null or not a TypeAttr");
        }
        return Sunsigned64(
            reinterpret_cast<uint64_t>(attr.getValue().getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::FunctionType::getNumInputs", (void*)+[](uint64_t type_ptr) -> ptr {
        auto t = mlir::dyn_cast_or_null<mlir::FunctionType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<void*>(type_ptr)));
        if (!t) {
          return scheme_error("mlir::FunctionType::getNumInputs",
                              "the pointer is null or not a FunctionType");
        }
        return Sunsigned64(t.getNumInputs());
      });

  Sregister_symbol(
      "mlir::FunctionType::getInput",
      (void*)+[](uint64_t type_ptr, uint64_t i) -> ptr {
        auto t = mlir::dyn_cast_or_null<mlir::FunctionType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<void*>(type_ptr)));
        if (!t) {
          return scheme_error("mlir::FunctionType::getInput",
                              "the pointer is null or not a FunctionType");
        }
        if (i >= t.getNumInputs()) {
          return scheme_error("mlir::FunctionType::getInput",
                              llvm::Twine("index ") + llvm::Twine(i) +
                                  " is out of range");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            t.getInput(static_cast<unsigned>(i)).getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::FunctionType::getNumResults",
      (void*)+[](uint64_t type_ptr) -> ptr {
        auto t = mlir::dyn_cast_or_null<mlir::FunctionType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<void*>(type_ptr)));
        if (!t) {
          return scheme_error("mlir::FunctionType::getNumResults",
                              "the pointer is null or not a FunctionType");
        }
        return Sunsigned64(t.getNumResults());
      });

  Sregister_symbol(
      "mlir::FunctionType::getResult",
      (void*)+[](uint64_t type_ptr, uint64_t i) -> ptr {
        auto t = mlir::dyn_cast_or_null<mlir::FunctionType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<void*>(type_ptr)));
        if (!t) {
          return scheme_error("mlir::FunctionType::getResult",
                              "the pointer is null or not a FunctionType");
        }
        if (i >= t.getNumResults()) {
          return scheme_error("mlir::FunctionType::getResult",
                              llvm::Twine("index ") + llvm::Twine(i) +
                                  " is out of range");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            t.getResult(static_cast<unsigned>(i)).getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::OpAsmPrinter::printRegion",
      (void*)+[](uint64_t printer_ptr, uint64_t region_ptr,
                 int skip_entry_block_args,
                 int print_block_terminators) -> ptr {
        if (!printer_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printRegion", "printer");
        }
        if (!region_ptr) {
          return nullPointer("mlir::OpAsmPrinter::printRegion", "region");
        }
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* r = reinterpret_cast<mlir::Region*>(region_ptr);
        p->printRegion(*r, static_cast<bool>(skip_entry_block_args),
                       static_cast<bool>(print_block_terminators));
        return Svoid;
      });

  // ===========================================================================
  // OpAsmParser bindings
  // ===========================================================================

  using UnresolvedOperands =
      CrestBox<llvm::SmallVector<mlir::OpAsmParser::UnresolvedOperand, 4>>;

  // LEAK WARNING: the list is on the C++ heap. Free it with
  // crest::OpAsmParser::freeOperands when it is no longer needed (the generated
  // parser of an assembly format does); resolveOperands only reads it.
  Sregister_symbol(
      "mlir::OpAsmParser::parseOperandList",
      (void*)+[](uint64_t parser_ptr, int64_t required) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseOperandList", "parser");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto* ops = new UnresolvedOperands;
        bool failed =
            required >= 0
                ? p->parseOperandList(ops->inner(), static_cast<int>(required))
                      .failed()
                : p->parseOperandList(ops->inner()).failed();
        if (failed) {
          delete ops;
          return Sunsigned64(0);
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(ops));
      });

  // LEAK WARNING: the list is on the C++ heap. Free it with
  // crest::OpAsmParser::freeOperands when it is no longer needed (the generated
  // parser of an assembly format does); resolveOperands only reads it.
  Sregister_symbol(
      "mlir::OpAsmParser::parseOperand",
      (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseOperand", "parser");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto* ops = new UnresolvedOperands;
        ops->inner().resize(1);
        if (p->parseOperand(ops->inner()[0]).failed()) {
          delete ops;
          return Sunsigned64(0);
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(ops));
      });

  // LEAK WARNING: the list is on the C++ heap. Free it with
  // crest::OpAsmParser::freeOperands when it is no longer needed (the generated
  // parser of an assembly format does); resolveOperands only reads it.
  Sregister_symbol(
      "mlir::OpAsmParser::parseOptionalOperand",
      (void*)+[](uint64_t parser_ptr) -> ptr {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto* ops = new UnresolvedOperands;
        ops->inner().resize(1);
        auto result = p->parseOptionalOperand(ops->inner()[0]);
        // OptionalParseResult: nullopt = not present, else
        // success/failure
        if (!result.has_value() || result.value().failed()) {
          delete ops;
          return Sunsigned64(0);
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(ops));
      });

  Sregister_symbol(
      "mlir::OpAsmParser::resolveOperands",
      (void*)+[](uint64_t parser_ptr, uint64_t ops_handle, uint64_t type_ptr,
                 uint64_t state_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::resolveOperands", "parser");
        }
        if (!type_ptr) {
          return nullPointer("mlir::OpAsmParser::resolveOperands", "type");
        }
        if (!state_ptr) {
          return nullPointer("mlir::OpAsmParser::resolveOperands", "state");
        }
        auto* ops = UnresolvedOperands::inner(ops_handle);
        if (!ops) {
          return scheme_error(
              "mlir::OpAsmParser::resolveOperands",
              "the operand list is null or not a list of operands");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        return scheme_bool(!p->resolveOperands(*ops, type, state.operands));
      });

  Sregister_symbol(
      "mlir::OpAsmParser::resolveOperandsFunctional",
      (void*)+[](uint64_t parser_ptr, uint64_t ops_handle,
                 uint64_t func_type_ptr, uint64_t state_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::resolveOperandsFunctional",
                             "parser");
        }
        auto ft = mlir::dyn_cast_or_null<mlir::FunctionType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(func_type_ptr)));
        if (!ft) {
          return scheme_error(
              "mlir::OpAsmParser::resolveOperandsFunctional",
              "the type pointer is null or not a function type");
        }
        if (!state_ptr) {
          return nullPointer("mlir::OpAsmParser::resolveOperandsFunctional",
                             "state");
        }
        auto* ops = UnresolvedOperands::inner(ops_handle);
        if (!ops) {
          return scheme_error(
              "mlir::OpAsmParser::resolveOperandsFunctional",
              "the operand list is null or not a list of operands");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        return scheme_bool(!p->resolveOperands(
            *ops, ft.getInputs(), p->getNameLoc(), state.operands));
      });

  // crest::OpAsmParser::freeOperands (uptr operands) → void
  //
  // Frees the list that parseOperand, parseOptionalOperand or parseOperandList
  // answered (0 is nothing). Nothing else frees it: resolveOperands only reads
  // it, so whoever parsed the list frees it when it is no longer needed.
  Sregister_symbol(
      "crest::OpAsmParser::freeOperands",
      (void*)+[](uint64_t ops_handle) -> ptr {
        if (!ops_handle) {
          return Svoid;
        }
        auto* ops = UnresolvedOperands::checked(ops_handle);
        if (!ops) {
          return scheme_error("crest::OpAsmParser::freeOperands",
                              "not a list of operands");
        }
        delete ops;
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseColonType",
      (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseColonType", "parser");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        mlir::Type t;
        if (p->parseColonType(t)) {
          return Sunsigned64(0);
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(t.getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseType", (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseType", "parser");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        mlir::Type t;
        if (p->parseType(t)) {
          return Sunsigned64(0);
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(t.getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseFunctionalType",
      (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseFunctionalType",
                             "parser");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        mlir::FunctionType type;
        if (p->parseType(type)) {
          return Sunsigned64(0);
        }
        return Sunsigned64(
            reinterpret_cast<uint64_t>(type.getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseOptionalAttrDict",
      (void*)+[](uint64_t parser_ptr, uint64_t state_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseOptionalAttrDict",
                             "parser");
        }
        if (!state_ptr) {
          return nullPointer("mlir::OpAsmParser::parseOptionalAttrDict",
                             "state");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        return scheme_bool(!p->parseOptionalAttrDict(state.attributes));
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseAttribute",
      (void*)+[](uint64_t parser_ptr, uint64_t state_ptr,
                 const char* attr_name) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseAttribute", "parser");
        }
        if (!state_ptr) {
          return nullPointer("mlir::OpAsmParser::parseAttribute", "state");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        mlir::Attribute attr;
        if (p->parseAttribute(attr, attr_name, state.attributes)) {
          return Sunsigned64(0);
        }
        return Sunsigned64(
            reinterpret_cast<uint64_t>(attr.getAsOpaquePointer()));
      });

  // parseAttribute with the type the attribute has when the text leaves it out,
  // as ODS does for a buildable attribute type (the I64Attr of an op).
  Sregister_symbol(
      "mlir::OpAsmParser::parseAttribute<Type>",
      (void*)+[](uint64_t parser_ptr, uint64_t state_ptr, uint64_t type_ptr,
                 const char* attr_name) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseAttribute<Type>",
                             "parser");
        }
        if (!state_ptr) {
          return nullPointer("mlir::OpAsmParser::parseAttribute<Type>",
                             "state");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        mlir::Attribute attr;
        if (p->parseAttribute(attr, type, attr_name, state.attributes)) {
          return Sunsigned64(0);
        }
        return Sunsigned64(
            reinterpret_cast<uint64_t>(attr.getAsOpaquePointer()));
      });

  Sregister_symbol(
      "mlir::AsmParser::getContext", (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::AsmParser::getContext", "parser");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        return Sunsigned64(reinterpret_cast<uint64_t>(p->getContext()));
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseKeyword",
      (void*)+[](uint64_t parser_ptr, const char* kw) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseKeyword", "parser");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        return scheme_bool(!p->parseKeyword(kw));
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseLParen", (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseLParen", "parser");
        }
        return scheme_bool(
            !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseLParen());
      });
  Sregister_symbol(
      "mlir::OpAsmParser::parseRParen", (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseRParen", "parser");
        }
        return scheme_bool(
            !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseRParen());
      });
  Sregister_symbol(
      "mlir::OpAsmParser::parseColon", (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseColon", "parser");
        }
        return scheme_bool(
            !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseColon());
      });
  Sregister_symbol(
      "mlir::OpAsmParser::parseComma", (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseComma", "parser");
        }
        return scheme_bool(
            !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseComma());
      });
  // parseOptionalComma — succeeds silently if no comma; returns 1 if comma
  // found.
  Sregister_symbol(
      "mlir::OpAsmParser::parseOptionalComma",
      (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseOptionalComma", "parser");
        }
        return scheme_bool(!reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)
                                ->parseOptionalComma());
      });
  Sregister_symbol(
      "mlir::OpAsmParser::parseArrow", (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseArrow", "parser");
        }
        return scheme_bool(
            !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseArrow());
      });
  Sregister_symbol(
      "mlir::OpAsmParser::parseLess", (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseLess", "parser");
        }
        return scheme_bool(
            !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseLess());
      });
  Sregister_symbol(
      "mlir::OpAsmParser::parseGreater",
      (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseGreater", "parser");
        }
        return scheme_bool(
            !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseGreater());
      });
  Sregister_symbol(
      "mlir::OpAsmParser::parseLSquare",
      (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseLSquare", "parser");
        }
        return scheme_bool(
            !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseLSquare());
      });
  Sregister_symbol(
      "mlir::OpAsmParser::parseRSquare",
      (void*)+[](uint64_t parser_ptr) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseRSquare", "parser");
        }
        return scheme_bool(
            !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseRSquare());
      });

  Sregister_symbol(
      "mlir::OpAsmParser::emitError",
      (void*)+[](uint64_t parser_ptr, const char* message) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::emitError", "parser");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        p->emitError(p->getNameLoc(), message);
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OpAsmParser::parseSymbolName",
      (void*)+[](uint64_t parser_ptr, uint64_t state_ptr,
                 const char* attr_name) -> ptr {
        if (!parser_ptr) {
          return nullPointer("mlir::OpAsmParser::parseSymbolName", "parser");
        }
        if (!state_ptr) {
          return nullPointer("mlir::OpAsmParser::parseSymbolName", "state");
        }
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        mlir::StringAttr sym;
        if (p->parseSymbolName(sym, attr_name, state.attributes)) {
          return Sstring("");
        }
        return Sstring(sym.getValue().data());
      });

  Sregister_symbol(
      "mlir::isa<FunctionType>", (void*)+[](uint64_t type_ptr) -> ptr {
        return scheme_bool(
            mlir::isa<mlir::FunctionType>(mlir::Type::getFromOpaquePointer(
                reinterpret_cast<void*>(type_ptr))));
      });

  Sregister_symbol(
      "mlir::OperationState::addType",
      (void*)+[](uint64_t state_ptr, uint64_t type_ptr) -> ptr {
        if (!state_ptr) {
          return nullPointer("mlir::OperationState::addType", "state");
        }
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        state.addTypes(mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr)));
        return Svoid;
      });
}

} // namespace crest

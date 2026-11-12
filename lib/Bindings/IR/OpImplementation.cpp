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

void registerIROpImplementationBindings() {
  // The methods of mlir::AsmPrinter, the base of OpAsmPrinter and of the
  // DialectAsmPrinter that a dialect's :print-type and :print-attribute get.
  // mlir::AsmPrinter::getStream (uptr printer) -> uptr llvm::raw_ostream*
  register_binding("mlir::AsmPrinter::getStream",
                   [](uint64_t printer_ptr) -> uint64_t {
                     auto* p = reinterpret_cast<mlir::AsmPrinter*>(printer_ptr);
                     return reinterpret_cast<uint64_t>(&p->getStream());
                   });
  register_binding("mlir::AsmPrinter::printType",
                   [](uint64_t printer_ptr, uint64_t type_ptr) -> void {
                     reinterpret_cast<mlir::AsmPrinter*>(printer_ptr)
                         ->printType(mlir::Type::getFromOpaquePointer(
                             reinterpret_cast<const void*>(type_ptr)));
                   });
  register_binding("mlir::AsmPrinter::printAttribute",
                   [](uint64_t printer_ptr, uint64_t attr_ptr) -> void {
                     reinterpret_cast<mlir::AsmPrinter*>(printer_ptr)
                         ->printAttribute(mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<const void*>(attr_ptr)));
                   });
  // The text as a keyword if it is one, else as a quoted string.
  register_binding("mlir::AsmPrinter::printKeywordOrString",
                   [](uint64_t printer_ptr, const char* text) -> void {
                     reinterpret_cast<mlir::AsmPrinter*>(printer_ptr)
                         ->printKeywordOrString(text);
                   });
  // The text as a quoted, escaped string.
  register_binding(
      "mlir::AsmPrinter::printString",
      [](uint64_t printer_ptr, const char* text) -> void {
        reinterpret_cast<mlir::AsmPrinter*>(printer_ptr)->printString(text);
      });

  register_binding("mlir::OpAsmPrinter::printString",
                   [](uint64_t printer_ptr, const char* s) -> void {
                     auto* p =
                         reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
                     *p << s;
                   });

  register_binding("mlir::OpAsmPrinter::printOperands",
                   [](uint64_t printer_ptr, uint64_t op_ptr) -> void {
                     auto* p =
                         reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
                     auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
                     *p << op->getOperands();
                   });

  register_binding("mlir::OpAsmPrinter::printOperand",
                   [](uint64_t printer_ptr, uint64_t value_ptr) -> void {
                     auto* p =
                         reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
                     auto v = mlir::Value::getFromOpaquePointer(
                         reinterpret_cast<void*>(value_ptr));
                     *p << v;
                   });

  register_binding("mlir::OpAsmPrinter::printAttributeWithoutType",
                   [](uint64_t printer_ptr, uint64_t attr_ptr) -> void {
                     auto* p =
                         reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
                     auto attr = mlir::Attribute::getFromOpaquePointer(
                         reinterpret_cast<void*>(attr_ptr));
                     p->printAttributeWithoutType(attr);
                   });

  register_binding("mlir::OpAsmPrinter::printAttribute",
                   [](uint64_t printer_ptr, uint64_t attr_ptr) -> void {
                     auto* p =
                         reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
                     auto attr = mlir::Attribute::getFromOpaquePointer(
                         reinterpret_cast<void*>(attr_ptr));
                     p->printAttribute(attr);
                   });

  register_binding("mlir::OpAsmPrinter::printType",
                   [](uint64_t printer_ptr, uint64_t type_ptr) -> void {
                     auto* p =
                         reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
                     auto t = mlir::Type::getFromOpaquePointer(
                         reinterpret_cast<void*>(type_ptr));
                     p->printType(t);
                   });

  register_binding("mlir::OpAsmPrinter::printOptionalAttrDict",
                   [](uint64_t printer_ptr, uint64_t op_ptr) -> void {
                     auto* p =
                         reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
                     auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
                     p->printOptionalAttrDict(op->getAttrs());
                   });

  register_binding(
      "mlir::OpAsmPrinter::printOptionalAttrDictExcept",
      [](uint64_t printer_ptr, uint64_t op_ptr, const char* elide) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        p->printOptionalAttrDict(op->getAttrs(),
                                 llvm::ArrayRef<llvm::StringRef>{elide});
      });

  // The attributes to leave out are a Scheme list of strings.
  register_binding(
      "mlir::OpAsmPrinter::printOptionalAttrDict<ArrayRef<StringRef>>",
      [](uint64_t printer_ptr, uint64_t op_ptr, ptr elided) -> void {
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
      });

  register_binding("mlir::OpAsmPrinter::printFunctionalType",
                   [](uint64_t printer_ptr, uint64_t op_ptr) -> void {
                     auto* p =
                         reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
                     auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
                     p->printFunctionalType(op);
                   });

  register_binding(
      "mlir::OpAsmPrinter::printResultTypes",
      [](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        llvm::interleaveComma(op->getResultTypes(), p->getStream(),
                              [&](mlir::Type t) { p->printType(t); });
      });

  register_binding("mlir::OpAsmPrinter::printSymbolName",
                   [](uint64_t printer_ptr, const char* name) -> void {
                     auto* p =
                         reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
                     p->printSymbolName(name);
                   });

  register_binding(
      "mlir::StringAttr::getValue", [](uint64_t attr_ptr) -> const char* {
        auto attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<void*>(attr_ptr));
        return mlir::cast<mlir::StringAttr>(attr).getValue().data();
      });

  register_binding(
      "mlir::TypeAttr::getValue", [](uint64_t attr_ptr) -> uint64_t {
        auto attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<void*>(attr_ptr));
        return reinterpret_cast<uint64_t>(
            mlir::cast<mlir::TypeAttr>(attr).getValue().getAsOpaquePointer());
      });

  register_binding(
      "mlir::FunctionType::getNumInputs", [](uint64_t type_ptr) -> uint64_t {
        auto t =
            mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr));
        return mlir::cast<mlir::FunctionType>(t).getNumInputs();
      });

  register_binding("mlir::FunctionType::getInput",
                   [](uint64_t type_ptr, uint64_t i) -> uint64_t {
                     auto t = mlir::Type::getFromOpaquePointer(
                         reinterpret_cast<void*>(type_ptr));
                     return reinterpret_cast<uint64_t>(
                         mlir::cast<mlir::FunctionType>(t)
                             .getInput(static_cast<unsigned>(i))
                             .getAsOpaquePointer());
                   });

  register_binding(
      "mlir::FunctionType::getNumResults", [](uint64_t type_ptr) -> uint64_t {
        auto t =
            mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr));
        return mlir::cast<mlir::FunctionType>(t).getNumResults();
      });

  register_binding("mlir::FunctionType::getResult",
                   [](uint64_t type_ptr, uint64_t i) -> uint64_t {
                     auto t = mlir::Type::getFromOpaquePointer(
                         reinterpret_cast<void*>(type_ptr));
                     return reinterpret_cast<uint64_t>(
                         mlir::cast<mlir::FunctionType>(t)
                             .getResult(static_cast<unsigned>(i))
                             .getAsOpaquePointer());
                   });

  register_binding(
      "mlir::OpAsmPrinter::printRegion",
      [](uint64_t printer_ptr, uint64_t region_ptr, int skip_entry_block_args,
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
      CrestBox<llvm::SmallVector<mlir::OpAsmParser::UnresolvedOperand, 4>>;

  // LEAK WARNING: the list is on the C++ heap. Free it with
  // crest::OpAsmParser::freeOperands when it is no longer needed (the generated
  // parser of an assembly format does); resolveOperands only reads it.
  register_binding("mlir::OpAsmParser::parseOperandList",
                   [](uint64_t parser_ptr, int64_t required) -> uint64_t {
                     auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
                     auto* ops = new UnresolvedOperands;
                     bool failed =
                         required >= 0
                             ? p->parseOperandList(ops->inner(),
                                                   static_cast<int>(required))
                                   .failed()
                             : p->parseOperandList(ops->inner()).failed();
                     if (failed) {
                       delete ops;
                       return 0;
                     }
                     return reinterpret_cast<uint64_t>(ops);
                   });

  // LEAK WARNING: the list is on the C++ heap. Free it with
  // crest::OpAsmParser::freeOperands when it is no longer needed (the generated
  // parser of an assembly format does); resolveOperands only reads it.
  register_binding("mlir::OpAsmParser::parseOperand",
                   [](uint64_t parser_ptr) -> uint64_t {
                     auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
                     auto* ops = new UnresolvedOperands;
                     ops->inner().resize(1);
                     if (p->parseOperand(ops->inner()[0]).failed()) {
                       delete ops;
                       return 0;
                     }
                     return reinterpret_cast<uint64_t>(ops);
                   });

  // LEAK WARNING: the list is on the C++ heap. Free it with
  // crest::OpAsmParser::freeOperands when it is no longer needed (the generated
  // parser of an assembly format does); resolveOperands only reads it.
  register_binding("mlir::OpAsmParser::parseOptionalOperand",
                   [](uint64_t parser_ptr) -> uint64_t {
                     auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
                     auto* ops = new UnresolvedOperands;
                     ops->inner().resize(1);
                     auto result = p->parseOptionalOperand(ops->inner()[0]);
                     // OptionalParseResult: nullopt = not present, else
                     // success/failure
                     if (!result.has_value() || result.value().failed()) {
                       delete ops;
                       return 0;
                     }
                     return reinterpret_cast<uint64_t>(ops);
                   });

  register_binding(
      "mlir::OpAsmParser::resolveOperands",
      [](uint64_t parser_ptr, uint64_t ops_handle, uint64_t type_ptr,
         uint64_t state_ptr) -> int {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto* ops = reinterpret_cast<UnresolvedOperands*>(ops_handle);
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        return !p->resolveOperands(ops->inner(), type, state.operands);
      });

  register_binding(
      "mlir::OpAsmParser::resolveOperandsFunctional",
      [](uint64_t parser_ptr, uint64_t ops_handle, uint64_t func_type_ptr,
         uint64_t state_ptr) -> int {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto* ops = reinterpret_cast<UnresolvedOperands*>(ops_handle);
        auto ft =
            mlir::cast<mlir::FunctionType>(mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(func_type_ptr)));
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        return !p->resolveOperands(ops->inner(), ft.getInputs(),
                                   p->getNameLoc(), state.operands);
      });

  // crest::OpAsmParser::freeOperands (uptr operands) → void
  //
  // Frees the list that parseOperand, parseOptionalOperand or parseOperandList
  // answered (0 is nothing). Nothing else frees it: resolveOperands only reads
  // it, so whoever parsed the list frees it when it is no longer needed.
  register_binding("crest::OpAsmParser::freeOperands",
                   [](uint64_t ops_handle) -> void {
                     delete reinterpret_cast<UnresolvedOperands*>(ops_handle);
                   });

  register_binding("mlir::OpAsmParser::parseColonType",
                   [](uint64_t parser_ptr) -> uint64_t {
                     auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
                     mlir::Type t;
                     if (p->parseColonType(t)) {
                       return 0;
                     }
                     return reinterpret_cast<uint64_t>(t.getAsOpaquePointer());
                   });

  register_binding("mlir::OpAsmParser::parseType",
                   [](uint64_t parser_ptr) -> uint64_t {
                     auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
                     mlir::Type t;
                     if (p->parseType(t)) {
                       return 0;
                     }
                     return reinterpret_cast<uint64_t>(t.getAsOpaquePointer());
                   });

  register_binding("mlir::OpAsmParser::parseFunctionalType",
                   [](uint64_t parser_ptr) -> uint64_t {
                     auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
                     mlir::FunctionType type;
                     if (p->parseType(type)) {
                       return 0;
                     }
                     return reinterpret_cast<uint64_t>(
                         type.getAsOpaquePointer());
                   });

  register_binding("mlir::OpAsmParser::parseOptionalAttrDict",
                   [](uint64_t parser_ptr, uint64_t state_ptr) -> int {
                     auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
                     auto& state =
                         *reinterpret_cast<mlir::OperationState*>(state_ptr);
                     return !p->parseOptionalAttrDict(state.attributes);
                   });

  register_binding(
      "mlir::OpAsmParser::parseAttribute",
      [](uint64_t parser_ptr, uint64_t state_ptr,
         const char* attr_name) -> uint64_t {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        mlir::Attribute attr;
        if (p->parseAttribute(attr, attr_name, state.attributes)) {
          return 0;
        }
        return reinterpret_cast<uint64_t>(attr.getAsOpaquePointer());
      });

  // parseAttribute with the type the attribute has when the text leaves it out,
  // as ODS does for a buildable attribute type (the I64Attr of an op).
  register_binding(
      "mlir::OpAsmParser::parseAttribute<Type>",
      [](uint64_t parser_ptr, uint64_t state_ptr, uint64_t type_ptr,
         const char* attr_name) -> uint64_t {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        mlir::Attribute attr;
        if (p->parseAttribute(attr, type, attr_name, state.attributes)) {
          return 0;
        }
        return reinterpret_cast<uint64_t>(attr.getAsOpaquePointer());
      });

  register_binding("mlir::AsmParser::getContext",
                   [](uint64_t parser_ptr) -> uint64_t {
                     auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
                     return reinterpret_cast<uint64_t>(p->getContext());
                   });

  register_binding("mlir::OpAsmParser::parseKeyword",
                   [](uint64_t parser_ptr, const char* kw) -> int {
                     auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
                     return !p->parseKeyword(kw);
                   });

  register_binding(
      "mlir::OpAsmParser::parseLParen", [](uint64_t parser_ptr) -> int {
        return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseLParen();
      });
  register_binding(
      "mlir::OpAsmParser::parseRParen", [](uint64_t parser_ptr) -> int {
        return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseRParen();
      });
  register_binding(
      "mlir::OpAsmParser::parseColon", [](uint64_t parser_ptr) -> int {
        return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseColon();
      });
  register_binding(
      "mlir::OpAsmParser::parseComma", [](uint64_t parser_ptr) -> int {
        return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseComma();
      });
  // parseOptionalComma — succeeds silently if no comma; returns 1 if comma
  // found.
  register_binding("mlir::OpAsmParser::parseOptionalComma",
                   [](uint64_t parser_ptr) -> int {
                     return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)
                                 ->parseOptionalComma();
                   });
  register_binding(
      "mlir::OpAsmParser::parseArrow", [](uint64_t parser_ptr) -> int {
        return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseArrow();
      });
  register_binding(
      "mlir::OpAsmParser::parseLess", [](uint64_t parser_ptr) -> int {
        return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)->parseLess();
      });
  register_binding("mlir::OpAsmParser::parseGreater",
                   [](uint64_t parser_ptr) -> int {
                     return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)
                                 ->parseGreater();
                   });
  register_binding("mlir::OpAsmParser::parseLSquare",
                   [](uint64_t parser_ptr) -> int {
                     return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)
                                 ->parseLSquare();
                   });
  register_binding("mlir::OpAsmParser::parseRSquare",
                   [](uint64_t parser_ptr) -> int {
                     return !reinterpret_cast<mlir::OpAsmParser*>(parser_ptr)
                                 ->parseRSquare();
                   });

  register_binding("mlir::OpAsmParser::emitError",
                   [](uint64_t parser_ptr, const char* message) -> void {
                     auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
                     p->emitError(p->getNameLoc(), message);
                   });

  register_binding("mlir::OpAsmParser::parseSymbolName",
                   [](uint64_t parser_ptr, uint64_t state_ptr,
                      const char* attr_name) -> ptr {
                     auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
                     auto& state =
                         *reinterpret_cast<mlir::OperationState*>(state_ptr);
                     mlir::StringAttr sym;
                     if (p->parseSymbolName(sym, attr_name, state.attributes)) {
                       return Sstring("");
                     }
                     return Sstring(sym.getValue().data());
                   });

  register_binding("mlir::isa<FunctionType>", [](uint64_t type_ptr) -> int {
    return mlir::isa<mlir::FunctionType>(mlir::Type::getFromOpaquePointer(
               reinterpret_cast<void*>(type_ptr)))
               ? 1
               : 0;
  });

  register_binding("mlir::OperationState::addType",
                   [](uint64_t state_ptr, uint64_t type_ptr) -> void {
                     auto& state =
                         *reinterpret_cast<mlir::OperationState*>(state_ptr);
                     state.addTypes(mlir::Type::getFromOpaquePointer(
                         reinterpret_cast<const void*>(type_ptr)));
                   });
}

} // namespace crest

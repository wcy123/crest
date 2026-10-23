/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/OpImplementation.h

#include "OpImplementation.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/IR/Operation.h"
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
}

} // namespace crest

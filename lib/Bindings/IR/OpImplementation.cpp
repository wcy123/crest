/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/OpImplementation.h

#include "OpImplementation.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/IR/Operation.h"
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
}

} // namespace crest

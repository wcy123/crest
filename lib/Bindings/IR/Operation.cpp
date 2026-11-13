/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Operation.h

#include "Operation.h"
#include "../Support/ArrayRef.h"
#include "../Support/Logging.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/raw_ostream.h"
#include "mlir/CAPI/IR.h"
#include "mlir/CAPI/Wrap.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Verifier.h"
#include <cstring>
#include <limits>
#include <type_traits>

namespace crest {

namespace {

// mlir::WalkResult is a class of one private enum, { Interrupt, Advance, Skip
// }. The Scheme side has its numbers as constants ((mlir Support WalkResult)),
// and a Scheme visitor is a C function that answers one.
int walkResultNumber(mlir::WalkResult result) {
  static_assert(sizeof(mlir::WalkResult) == sizeof(int) &&
                    std::is_trivially_copyable_v<mlir::WalkResult>,
                "mlir::WalkResult is no longer one int: update "
                "(mlir Support WalkResult) and the callables of walk");
  int number;
  std::memcpy(&number, &result, sizeof number);
  return number;
}

} // namespace

void registerIROperationBindings() {
  if (walkResultNumber(mlir::WalkResult::interrupt()) != 0 ||
      walkResultNumber(mlir::WalkResult::advance()) != 1 ||
      walkResultNumber(mlir::WalkResult::skip()) != 2) {
    llvm::report_fatal_error(
        "mlir::WalkResult changed: update the constants of "
        "(mlir Support WalkResult)",
        false);
  }
  Sregister_symbol(
      "mlir::Operation::getName", (void*)+[](uint64_t op) -> ptr {
        if (!op) {
          return scheme_string("");
        }
        return scheme_string(reinterpret_cast<mlir::Operation*>(op)
                                 ->getName()
                                 .getStringRef()
                                 .data());
      });
  Sregister_symbol(
      "mlir::Operation::getContext", (void*)+[](uint64_t op) -> ptr {
        if (!op) {
          return scheme_error("mlir::Operation::getContext",
                              "operation must not be null");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::Operation*>(op)->getContext()));
      });
  Sregister_symbol(
      "mlir::Operation::getNumOperands", (void*)+[](uint64_t op) -> ptr {
        if (!op) {
          return scheme_error("mlir::Operation::getNumOperands",
                              "operation must not be null");
        }
        return Sinteger64(
            reinterpret_cast<mlir::Operation*>(op)->getNumOperands());
      });
  Sregister_symbol(
      "mlir::Operation::getNumResults", (void*)+[](uint64_t op) -> ptr {
        if (!op) {
          return scheme_error("mlir::Operation::getNumResults",
                              "operation must not be null");
        }
        return Sinteger64(
            reinterpret_cast<mlir::Operation*>(op)->getNumResults());
      });
  Sregister_symbol(
      "mlir::Operation::getOperand",
      (void*)+[](uint64_t op, int64_t index) -> ptr {
        if (!op) {
          return scheme_error("mlir::Operation::getOperand",
                              "operation must not be null");
        }
        auto* cppOp = reinterpret_cast<mlir::Operation*>(op);
        if (index < 0 || index >= (int64_t)cppOp->getNumOperands()) {
          return scheme_error(
              "mlir::Operation::getOperand",
              llvm::Twine("index out of range: ") + " " + llvm::Twine(index) +
                  " " + " (size " + " " +
                  llvm::Twine((int64_t)cppOp->getNumOperands()) + " " + ")");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            cppOp->getOperand(static_cast<unsigned>(index))
                .getAsOpaquePointer()));
      });
  Sregister_symbol(
      "mlir::Operation::getOpOperand",
      (void*)+[](uint64_t op, int64_t index) -> ptr {
        if (!op) {
          return scheme_error("mlir::Operation::getOpOperand",
                              "operation must not be null");
        }
        mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op);
        if (index < 0 || index >= (int64_t)cppOp->getNumOperands()) {
          return scheme_error(
              "mlir::Operation::getOpOperand",
              llvm::Twine("index out of range: ") + " " + llvm::Twine(index) +
                  " " + " (size " + " " +
                  llvm::Twine((int64_t)cppOp->getNumOperands()) + " " + ")");
        }
        mlir::Value val = cppOp->getOperand(static_cast<unsigned>(index));
        MlirValue cVal = wrap(val);
        return Sunsigned64(
            reinterpret_cast<uint64_t>(const_cast<void*>(cVal.ptr)));
      });
  Sregister_symbol(
      "mlir::Operation::getResult",
      (void*)+[](uint64_t op, int64_t index) -> ptr {
        if (!op) {
          return scheme_error("mlir::Operation::getResult",
                              "operation must not be null");
        }
        mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op);
        if (index < 0 || index >= (int64_t)cppOp->getNumResults()) {
          return scheme_error("mlir::Operation::getResult",
                              llvm::Twine("index out of range: ") + " " +
                                  llvm::Twine(index) + " " + " (size " + " " +
                                  llvm::Twine((int64_t)cppOp->getNumResults()) +
                                  " " + ")");
        }
        mlir::Value val = cppOp->getResult(static_cast<unsigned>(index));
        MlirValue cVal = wrap(val);
        return Sunsigned64(
            reinterpret_cast<uint64_t>(const_cast<void*>(cVal.ptr)));
      });
  Sregister_symbol(
      "mlir::Operation::getParentOp", (void*)+[](uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::Operation::getParentOp",
                              "operation must not be null");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::Operation*>(op_ptr)->getParentOp()));
      });
  Sregister_symbol(
      "mlir::OpOperand::get",
      (void*)+[](uint64_t op_ptr, int64_t index) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::OpOperand::get",
                              "operation must not be null");
        }
        mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        if (index < 0 || index >= (int64_t)op->getNumOperands()) {
          return scheme_error("mlir::OpOperand::get",
                              llvm::Twine("index out of range: ") + " " +
                                  llvm::Twine(index) + " " + " (size " + " " +
                                  llvm::Twine((int64_t)op->getNumOperands()) +
                                  " " + ")");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            const_cast<void*>(op->getOperand(static_cast<unsigned>(index))
                                  .getAsOpaquePointer())));
      });
  Sregister_symbol(
      "mlir::OpResult::getOwner",
      (void*)+[](uint64_t op_ptr, int64_t index) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::OpResult::getOwner",
                              "operation must not be null");
        }
        mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        if (index < 0 || index >= (int64_t)op->getNumResults()) {
          return scheme_error("mlir::OpResult::getOwner",
                              llvm::Twine("index out of range: ") + " " +
                                  llvm::Twine(index) + " " + " (size " + " " +
                                  llvm::Twine((int64_t)op->getNumResults()) +
                                  " " + ")");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(const_cast<void*>(
            op->getResult(static_cast<unsigned>(index)).getAsOpaquePointer())));
      });
  Sregister_symbol(
      "mlir::Operation::getLoc", (void*)+[](uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::Operation::getLoc",
                              "operation must not be null");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            const_cast<void*>(reinterpret_cast<mlir::Operation*>(op_ptr)
                                  ->getLoc()
                                  .getAsOpaquePointer())));
      });
  // mlir::Operation::walk (uptr op) (callable visit) -> the WalkResult of the
  // walk, as a number
  //
  // `visit` is a C function with the prototype of MLIR's visitor,
  // WalkResult(Operation*), that Scheme made and keeps alive until the walk
  // returns. It answers one of the constants of (mlir Support WalkResult); an
  // error of the Scheme procedure is a diagnostic, and the callable answers
  // interrupt, which stops the walk.
  Sregister_symbol(
      "mlir::Operation::walk",
      (void*)+[](uint64_t op, mlir::WalkResult (*visit)(uint64_t)) -> ptr {
        if (!op) {
          return Sinteger64(walkResultNumber(mlir::WalkResult::advance()));
        }
        mlir::WalkResult result = reinterpret_cast<mlir::Operation*>(op)->walk(
            [&](mlir::Operation* walkOp) -> mlir::WalkResult {
              return visit(reinterpret_cast<uint64_t>(walkOp));
            });
        return Sinteger64(walkResultNumber(result));
      });
  Sregister_symbol(
      "mlir::Operation::setOperand",
      (void*)+[](uint64_t op_ptr, int index, uint64_t value) -> ptr {
        if (!op_ptr || !value) {
          return Svoid;
        }
        mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        mlir::Value val =
            unwrap(MlirValue{reinterpret_cast<const void*>(value)});
        op->setOperand(static_cast<unsigned>(index), val);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::Operation::use_empty", (void*)+[](uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return Sinteger64(1);
        }
        return Sinteger64(
            reinterpret_cast<mlir::Operation*>(op_ptr)->use_empty() ? 1 : 0);
      });
  Sregister_symbol(
      "mlir::Operation::getAttrOfType<StringAttr>",
      (void*)+[](uint64_t op_ptr, const char* attr_name) -> ptr {
        if (!op_ptr) {
          return scheme_string("");
        }
        auto attr = reinterpret_cast<mlir::Operation*>(op_ptr)
                        ->getAttrOfType<mlir::StringAttr>(attr_name);
        if (!attr) {
          return scheme_string("");
        }
        return scheme_string(attr.getValue().data());
      });
  Sregister_symbol(
      "mlir::Operation::getAttrOfType<IntegerAttr>",
      (void*)+[](uint64_t op_ptr, const char* attr_name,
                 int64_t default_val) -> ptr {
        if (!op_ptr) {
          return Sinteger64(default_val);
        }
        if (auto attr = reinterpret_cast<mlir::Operation*>(op_ptr)
                            ->getAttrOfType<mlir::IntegerAttr>(attr_name)) {
          return Sinteger64(attr.getValue().getSExtValue());
        }
        return Sinteger64(default_val);
      });
  Sregister_symbol(
      "mlir::Operation::hasAttr",
      (void*)+[](uint64_t op_ptr, const char* attr_name) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::Operation::hasAttr",
                              "operation must not be null");
        }
        return Sinteger64(
            reinterpret_cast<mlir::Operation*>(op_ptr)->hasAttr(attr_name) ? 1
                                                                           : 0);
      });
  // mlir::verify: 1 when the operation and everything nested in it verifies,
  // else 0 (the diagnostics are emitted).
  Sregister_symbol(
      "mlir::Operation::verify", (void*)+[](uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::Operation::verify",
                              "operation must not be null");
        }
        return Sinteger64(mlir::succeeded(mlir::verify(
                              reinterpret_cast<mlir::Operation*>(op_ptr)))
                              ? 1
                              : 0);
      });
  Sregister_symbol(
      "mlir::Operation::emitError",
      (void*)+[](uint64_t op_ptr, const char* msg) -> ptr {
        if (!op_ptr) {
          mlir_support_logging_error(msg);
          return Svoid;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->emitError(msg);
        return Svoid;
      });
  // mlir::Operation::emitOpError (uptr op, string message) -> void
  //
  // An error that names the op: "'dialect.op' op message".
  Sregister_symbol(
      "mlir::Operation::emitOpError",
      (void*)+[](uint64_t op_ptr, const char* msg) -> ptr {
        reinterpret_cast<mlir::Operation*>(op_ptr)->emitOpError(msg);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::Operation::emitWarning",
      (void*)+[](uint64_t op_ptr, const char* msg) -> ptr {
        if (!op_ptr) {
          mlir_support_logging_warning(msg);
          return Svoid;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->emitWarning(msg);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::Operation::emitRemark",
      (void*)+[](uint64_t op_ptr, const char* msg) -> ptr {
        if (!op_ptr) {
          mlir_support_logging_info(msg);
          return Svoid;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->emitRemark(msg);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::Operation::print", (void*)+[](uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return Sstring("");
        }
        std::string str;
        llvm::raw_string_ostream os(str);
        reinterpret_cast<mlir::Operation*>(op_ptr)->print(
            os, mlir::OpPrintingFlags().assumeVerified());
        return Sstring(str.c_str());
      });
  Sregister_symbol(
      "mlir::Operation::erase", (void*)+[](uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return Svoid;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->erase();
        return Svoid;
      });
  Sregister_symbol(
      "mlir::Operation::getAttrDictionary", (void*)+[](uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::Operation::getAttrDictionary",
                              "null op pointer");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::Operation*>(op_ptr)
                ->getAttrDictionary()
                .getAsOpaquePointer()));
      });
  Sregister_symbol(
      "mlir::Operation::setAttrs",
      (void*)+[](uint64_t op_ptr, uint64_t dict_ptr) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::Operation::setAttrs", "null op pointer");
        }
        if (!dict_ptr) {
          return scheme_error("mlir::Operation::setAttrs", "null dict pointer");
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->setAttrs(
            mlir::DictionaryAttr::getFromOpaquePointer(
                reinterpret_cast<const void*>(dict_ptr)));
        return Svoid;
      });
  Sregister_symbol(
      "mlir::Operation::getRegion",
      (void*)+[](uint64_t op_ptr, int region_idx) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::Operation::getRegion",
                              "operation must not be null");
        }
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        if (region_idx < 0 || region_idx >= (int)op->getNumRegions()) {
          return scheme_error(
              "mlir::Operation::getRegion",
              llvm::Twine("index out of range: ") + " " +
                  llvm::Twine((int64_t)region_idx) + " " + " (size " + " " +
                  llvm::Twine((int64_t)op->getNumRegions()) + " " + ")");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            &op->getRegion(static_cast<unsigned>(region_idx))));
      });
  Sregister_symbol(
      "mlir::Operation::getAttr",
      (void*)+[](uint64_t op_ptr, const char* name) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::Operation::getAttr",
                              "operation must not be null");
        }
        if (!name) {
          return scheme_error("mlir::Operation::getAttr",
                              "attribute name must not be null");
        }
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto attr = op->getAttr(name);
        return Sunsigned64(
            attr ? reinterpret_cast<uint64_t>(attr.getAsOpaquePointer()) : 0);
      });
  Sregister_symbol(
      "mlir::Operation::setAttr",
      (void*)+[](uint64_t op_ptr, const char* name, uint64_t attr_ptr) -> ptr {
        if (!op_ptr || !attr_ptr) {
          return Svoid;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->setAttr(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
        return Svoid;
      });
  // Aliases with ? and ! suffix (Scheme predicate/mutator convention)
  Sregister_symbol(
      "mlir::Operation::use_empty?", (void*)+[](uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return Sinteger64(1);
        }
        return Sinteger64(
            reinterpret_cast<mlir::Operation*>(op_ptr)->use_empty() ? 1 : 0);
      });
  Sregister_symbol(
      "mlir::Operation::hasAttr?",
      (void*)+[](uint64_t op_ptr, const char* attr_name) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::Operation::hasAttr?",
                              "operation must not be null");
        }
        return Sinteger64(
            reinterpret_cast<mlir::Operation*>(op_ptr)->hasAttr(attr_name) ? 1
                                                                           : 0);
      });
  Sregister_symbol(
      "mlir::Operation::setAttr!",
      (void*)+[](uint64_t op_ptr, const char* name, uint64_t attr_ptr) -> ptr {
        if (!op_ptr || !attr_ptr) {
          return Svoid;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->setAttr(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
        return Svoid;
      });
  // mlir::Operation::removeAttr (uptr op, string name) -> uptr
  //
  // Removes the attribute and answers it, or 0 when the op has none of that
  // name.
  Sregister_symbol(
      "mlir::Operation::removeAttr",
      (void*)+[](uint64_t op_ptr, const char* name) -> ptr {
        if (!op_ptr || !name) {
          return Sunsigned64(0);
        }
        mlir::Attribute removed =
            reinterpret_cast<mlir::Operation*>(op_ptr)->removeAttr(name);
        return Sunsigned64(
            reinterpret_cast<uint64_t>(removed.getAsOpaquePointer()));
      });
  Sregister_symbol(
      "mlir::Operation::emitError!",
      (void*)+[](uint64_t op_ptr, const char* msg) -> ptr {
        if (!op_ptr) {
          mlir_support_logging_error(msg);
          return Svoid;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->emitError(msg);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::Operation::getAttrOfType<FloatAttr>",
      (void*)+[](uint64_t op_ptr, const char* name) -> ptr {
        if (!op_ptr || !name) {
          return Sflonum(std::numeric_limits<double>::quiet_NaN());
        }
        auto attr = reinterpret_cast<mlir::Operation*>(op_ptr)
                        ->getAttrOfType<mlir::FloatAttr>(name);
        return Sflonum(attr ? attr.getValueAsDouble()
                            : std::numeric_limits<double>::quiet_NaN());
      });

  Sregister_symbol(
      "mlir::Operation::dump", (void*)+[](uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return Svoid;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->dump();
        return Svoid;
      });

  Sregister_symbol(
      "mlir::OperationName::getStringRef",
      (void*)+[](uint64_t op_name_ptr) -> ptr {
        auto* name = reinterpret_cast<mlir::OperationName*>(op_name_ptr);
        return scheme_string(name->getStringRef().data());
      });

  Sregister_symbol(
      "mlir::Operation::getBlock", (void*)+[](uint64_t op_ptr) -> ptr {
        return Sunsigned64(reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::Operation*>(op_ptr)->getBlock()));
      });

  Sregister_symbol(
      "mlir::Operation::moveBefore",
      (void*)+[](uint64_t op_ptr, uint64_t other_ptr) -> ptr {
        reinterpret_cast<mlir::Operation*>(op_ptr)->moveBefore(
            reinterpret_cast<mlir::Operation*>(other_ptr));
        return Svoid;
      });

  Sregister_symbol(
      "mlir::Operation::setOperands",
      (void*)+[](uint64_t op_ptr, uint64_t arr_ptr) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* arr = reinterpret_cast<CArrayRef<uintptr_t>*>(arr_ptr);
        llvm::SmallVector<mlir::Value> values;
        values.reserve(arr->size);
        for (size_t i = 0; i < arr->size; ++i) {
          values.push_back(mlir::Value::getFromOpaquePointer(
              reinterpret_cast<const void*>(arr->data[i])));
        }
        op->setOperands(values);
        return Svoid;
      });

  // mlir::Operation::getParentOfType<ModuleOp>: get enclosing module.
  // (op-ptr) → Operation* uptr (or 0)
  Sregister_symbol(
      "mlir::Operation::getParentOfType<ModuleOp>",
      (void*)+[](uint64_t op_ptr) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto parent = op->getParentOfType<mlir::ModuleOp>();
        if (!parent) {
          return Sunsigned64(0);
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(parent.getOperation()));
      });
}

} // namespace crest

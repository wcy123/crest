/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Operation.h

#include "Operation.h"
#include "../Support/LockedSchemeObject.h"
#include "../Support/Logging.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/CAPI/IR.h"
#include "mlir/CAPI/Wrap.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Operation.h"
#include <limits>

namespace crest {

void registerIROperationBindings() {
  Sregister_symbol(
      "mlir::Operation::getName", (void*)+[](uint64_t op) -> const char* {
        if (!op) {
          return "";
        }
        return reinterpret_cast<mlir::Operation*>(op)
            ->getName()
            .getStringRef()
            .data();
      });
  Sregister_symbol(
      "mlir::Operation::getContext", (void*)+[](uint64_t op) -> uint64_t {
        if (!op) {
          scheme_error("mlir::Operation::getContext",
                       "operation must not be null");
        }
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::Operation*>(op)->getContext());
      });
  Sregister_symbol(
      "mlir::Operation::getNumOperands", (void*)+[](uint64_t op) -> int64_t {
        if (!op) {
          scheme_error("mlir::Operation::getNumOperands",
                       "operation must not be null");
        }
        return reinterpret_cast<mlir::Operation*>(op)->getNumOperands();
      });
  Sregister_symbol(
      "mlir::Operation::getNumResults", (void*)+[](uint64_t op) -> int64_t {
        if (!op) {
          scheme_error("mlir::Operation::getNumResults",
                       "operation must not be null");
        }
        return reinterpret_cast<mlir::Operation*>(op)->getNumResults();
      });
  Sregister_symbol(
      "mlir::Operation::getOpOperand",
      (void*)+[](uint64_t op, int64_t index) -> uint64_t {
        if (!op) {
          scheme_error("mlir::Operation::getOpOperand",
                       "operation must not be null");
        }
        mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op);
        if (index < 0 || index >= (int64_t)cppOp->getNumOperands()) {
          scheme_error("mlir::Operation::getOpOperand",
                       "index out of range: ", index, " (size ",
                       (int64_t)cppOp->getNumOperands(), ")");
        }
        mlir::Value val = cppOp->getOperand(index);
        MlirValue cVal = wrap(val);
        return reinterpret_cast<uint64_t>(const_cast<void*>(cVal.ptr));
      });
  Sregister_symbol(
      "mlir::Operation::getResult",
      (void*)+[](uint64_t op, int64_t index) -> uint64_t {
        if (!op) {
          scheme_error("mlir::Operation::getResult",
                       "operation must not be null");
        }
        mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op);
        if (index < 0 || index >= (int64_t)cppOp->getNumResults()) {
          scheme_error("mlir::Operation::getResult",
                       "index out of range: ", index, " (size ",
                       (int64_t)cppOp->getNumResults(), ")");
        }
        mlir::Value val = cppOp->getResult(index);
        MlirValue cVal = wrap(val);
        return reinterpret_cast<uint64_t>(const_cast<void*>(cVal.ptr));
      });
  Sregister_symbol(
      "mlir::Operation::getParentOp", (void*)+[](uint64_t op_ptr) -> uint64_t {
        if (!op_ptr) {
          scheme_error("mlir::Operation::getParentOp",
                       "operation must not be null");
        }
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::Operation*>(op_ptr)->getParentOp());
      });
  Sregister_symbol(
      "mlir::OpOperand::get",
      (void*)+[](uint64_t op_ptr, int64_t index) -> uint64_t {
        if (!op_ptr) {
          scheme_error("mlir::OpOperand::get", "operation must not be null");
        }
        mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        if (index < 0 || index >= (int64_t)op->getNumOperands()) {
          scheme_error("mlir::OpOperand::get", "index out of range: ", index,
                       " (size ", (int64_t)op->getNumOperands(), ")");
        }
        return reinterpret_cast<uint64_t>(
            const_cast<void*>(op->getOperand(index).getAsOpaquePointer()));
      });
  Sregister_symbol(
      "mlir::OpResult::getOwner",
      (void*)+[](uint64_t op_ptr, int64_t index) -> uint64_t {
        if (!op_ptr) {
          scheme_error("mlir::OpResult::getOwner",
                       "operation must not be null");
        }
        mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        if (index < 0 || index >= (int64_t)op->getNumResults()) {
          scheme_error("mlir::OpResult::getOwner",
                       "index out of range: ", index, " (size ",
                       (int64_t)op->getNumResults(), ")");
        }
        return reinterpret_cast<uint64_t>(
            const_cast<void*>(op->getResult(index).getAsOpaquePointer()));
      });
  Sregister_symbol(
      "mlir::Operation::getLoc", (void*)+[](uint64_t op_ptr) -> uint64_t {
        if (!op_ptr) {
          scheme_error("mlir::Operation::getLoc", "operation must not be null");
        }
        return reinterpret_cast<uint64_t>(
            const_cast<void*>(reinterpret_cast<mlir::Operation*>(op_ptr)
                                  ->getLoc()
                                  .getAsOpaquePointer()));
      });
  Sregister_symbol(
      "mlir::Operation::walk", (void*)+[](uint64_t op, ptr callback) -> void {
        if (!op) {
          return;
        }
        mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op);
        crest::LockedSchemeObject locked(callback);
        cppOp->walk([&locked](mlir::Operation* walkOp) {
          ptr schemeOp = Sunsigned64(reinterpret_cast<uint64_t>(walkOp));
          scheme_call(locked.get(), schemeOp);
        });
      });
  Sregister_symbol(
      "mlir::Operation::setOperand",
      (void*)+[](uint64_t op_ptr, int index, uint64_t value) -> void {
        if (!op_ptr || !value) {
          return;
        }
        mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        mlir::Value val =
            unwrap(MlirValue{reinterpret_cast<const void*>(value)});
        op->setOperand(static_cast<unsigned>(index), val);
      });
  Sregister_symbol(
      "mlir::Operation::use_empty", (void*)+[](uint64_t op_ptr) -> int {
        if (!op_ptr) {
          return 1;
        }
        return reinterpret_cast<mlir::Operation*>(op_ptr)->use_empty() ? 1 : 0;
      });
  Sregister_symbol(
      "mlir::Operation::getAttrOfType<StringAttr>",
      (void*)+[](uint64_t op_ptr, const char* attr_name) -> const char* {
        if (!op_ptr) {
          return "";
        }
        auto attr = reinterpret_cast<mlir::Operation*>(op_ptr)
                        ->getAttrOfType<mlir::StringAttr>(attr_name);
        if (!attr) {
          return "";
        }
        return attr.getValue().data();
      });
  Sregister_symbol(
      "mlir::Operation::getAttrOfType<IntegerAttr>",
      (void*)+[](uint64_t op_ptr, const char* attr_name,
                 int64_t default_val) -> int64_t {
        if (!op_ptr) {
          return default_val;
        }
        if (auto attr = reinterpret_cast<mlir::Operation*>(op_ptr)
                            ->getAttrOfType<mlir::IntegerAttr>(attr_name)) {
          return attr.getValue().getSExtValue();
        }
        return default_val;
      });
  Sregister_symbol(
      "mlir::Operation::hasAttr",
      (void*)+[](uint64_t op_ptr, const char* attr_name) -> int {
        if (!op_ptr) {
          scheme_error("mlir::Operation::hasAttr",
                       "operation must not be null");
        }
        return reinterpret_cast<mlir::Operation*>(op_ptr)->hasAttr(attr_name)
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "mlir::Operation::emitError",
      (void*)+[](uint64_t op_ptr, const char* msg) -> void {
        if (!op_ptr) {
          mlir_support_logging_error(msg);
          return;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->emitError(msg);
      });
  Sregister_symbol(
      "mlir::Operation::emitWarning",
      (void*)+[](uint64_t op_ptr, const char* msg) -> void {
        if (!op_ptr) {
          mlir_support_logging_warning(msg);
          return;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->emitWarning(msg);
      });
  Sregister_symbol(
      "mlir::Operation::emitRemark",
      (void*)+[](uint64_t op_ptr, const char* msg) -> void {
        if (!op_ptr) {
          mlir_support_logging_info(msg);
          return;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->emitRemark(msg);
      });
  Sregister_symbol(
      "mlir::Operation::erase", (void*)+[](uint64_t op_ptr) -> void {
        if (!op_ptr) {
          return;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->erase();
      });
  Sregister_symbol(
      "mlir::Operation::getAttrDictionary",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        if (!op_ptr) {
          scheme_error("mlir::Operation::getAttrDictionary", "null op pointer");
        }
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::Operation*>(op_ptr)
                ->getAttrDictionary()
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::Operation::setAttrs",
      (void*)+[](uint64_t op_ptr, uint64_t dict_ptr) -> void {
        if (!op_ptr) {
          scheme_error("mlir::Operation::setAttrs", "null op pointer");
        }
        if (!dict_ptr) {
          scheme_error("mlir::Operation::setAttrs", "null dict pointer");
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->setAttrs(
            mlir::DictionaryAttr::getFromOpaquePointer(
                reinterpret_cast<const void*>(dict_ptr)));
      });
  Sregister_symbol(
      "mlir::Operation::getRegion",
      (void*)+[](uint64_t op_ptr, int region_idx) -> uint64_t {
        if (!op_ptr) {
          scheme_error("mlir::Operation::getRegion",
                       "operation must not be null");
        }
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        if (region_idx < 0 || region_idx >= (int)op->getNumRegions()) {
          scheme_error("mlir::Operation::getRegion",
                       "index out of range: ", (int64_t)region_idx, " (size ",
                       (int64_t)op->getNumRegions(), ")");
        }
        return reinterpret_cast<uint64_t>(&op->getRegion(region_idx));
      });
  Sregister_symbol(
      "mlir::Operation::getAttr",
      (void*)+[](uint64_t op_ptr, const char* name) -> uint64_t {
        if (!op_ptr) {
          scheme_error("mlir::Operation::getAttr",
                       "operation must not be null");
        }
        if (!name) {
          scheme_error("mlir::Operation::getAttr",
                       "attribute name must not be null");
        }
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto attr = op->getAttr(name);
        return attr ? reinterpret_cast<uint64_t>(attr.getAsOpaquePointer()) : 0;
      });
  Sregister_symbol(
      "mlir::Operation::setAttr",
      (void*)+[](uint64_t op_ptr, const char* name, uint64_t attr_ptr) -> void {
        if (!op_ptr || !attr_ptr) {
          return;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->setAttr(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
      });
  // Aliases with ? and ! suffix (Scheme predicate/mutator convention)
  Sregister_symbol(
      "mlir::Operation::use_empty?", (void*)+[](uint64_t op_ptr) -> int {
        if (!op_ptr) {
          return 1;
        }
        return reinterpret_cast<mlir::Operation*>(op_ptr)->use_empty() ? 1 : 0;
      });
  Sregister_symbol(
      "mlir::Operation::hasAttr?",
      (void*)+[](uint64_t op_ptr, const char* attr_name) -> int {
        if (!op_ptr) {
          scheme_error("mlir::Operation::hasAttr?",
                       "operation must not be null");
        }
        return reinterpret_cast<mlir::Operation*>(op_ptr)->hasAttr(attr_name)
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "mlir::Operation::setAttr!",
      (void*)+[](uint64_t op_ptr, const char* name, uint64_t attr_ptr) -> void {
        if (!op_ptr || !attr_ptr) {
          return;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->setAttr(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
      });
  Sregister_symbol(
      "mlir::Operation::emitError!",
      (void*)+[](uint64_t op_ptr, const char* msg) -> void {
        if (!op_ptr) {
          mlir_support_logging_error(msg);
          return;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->emitError(msg);
      });
  Sregister_symbol(
      "mlir::Operation::getAttrOfType<FloatAttr>",
      (void*)+[](uint64_t op_ptr, const char* name) -> double {
        if (!op_ptr || !name) {
          return std::numeric_limits<double>::quiet_NaN();
        }
        auto attr = reinterpret_cast<mlir::Operation*>(op_ptr)
                        ->getAttrOfType<mlir::FloatAttr>(name);
        return attr ? attr.getValueAsDouble()
                    : std::numeric_limits<double>::quiet_NaN();
      });
}

} // namespace crest

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

extern "C" {

const char* mlir_ir_operation_get_name(uint64_t op) {
  if (!op) {
    return "";
  }
  return reinterpret_cast<mlir::Operation*>(op)
      ->getName()
      .getStringRef()
      .data();
}

static uint64_t mlir_ir_operation_get_context(uint64_t op) {
  if (!op) {
    scheme_error("mlir-ir-operation-get-context", "operation must not be null");
  }
  return reinterpret_cast<uint64_t>(
      reinterpret_cast<mlir::Operation*>(op)->getContext());
}

static int64_t mlir_ir_operation_get_num_operands(uint64_t op) {
  if (!op) {
    scheme_error("mlir-ir-operation-get-num-operands",
                 "operation must not be null");
  }
  return reinterpret_cast<mlir::Operation*>(op)->getNumOperands();
}

static int64_t mlir_ir_operation_get_num_results(uint64_t op) {
  if (!op) {
    scheme_error("mlir-ir-operation-get-num-results",
                 "operation must not be null");
  }
  return reinterpret_cast<mlir::Operation*>(op)->getNumResults();
}

static uint64_t mlir_ir_operation_get_op_operand(uint64_t op, int64_t index) {
  if (!op) {
    scheme_error("mlir-ir-operation-get-op-operand",
                 "operation must not be null");
  }
  mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op);
  if (index < 0 || index >= (int64_t)cppOp->getNumOperands()) {
    scheme_error("mlir-ir-operation-get-op-operand",
                 "index out of range: ", index, " (size ",
                 (int64_t)cppOp->getNumOperands(), ")");
  }
  mlir::Value val = cppOp->getOperand(index);
  MlirValue cVal = wrap(val);
  return reinterpret_cast<uint64_t>(const_cast<void*>(cVal.ptr));
}

static uint64_t mlir_ir_operation_get_result(uint64_t op, int64_t index) {
  if (!op) {
    scheme_error("mlir-ir-operation-get-result", "operation must not be null");
  }
  mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op);
  if (index < 0 || index >= (int64_t)cppOp->getNumResults()) {
    scheme_error("mlir-ir-operation-get-result", "index out of range: ", index,
                 " (size ", (int64_t)cppOp->getNumResults(), ")");
  }
  mlir::Value val = cppOp->getResult(index);
  MlirValue cVal = wrap(val);
  return reinterpret_cast<uint64_t>(const_cast<void*>(cVal.ptr));
}

static ptr mlir_ir_operation_get_parent_op(ptr op_ptr) {
  if (!op_ptr) {
    scheme_error("mlir-ir-operation-get-parent-op",
                 "operation must not be null");
  }
  return static_cast<mlir::Operation*>(op_ptr)->getParentOp();
}

static ptr mlir_ir_op_operand_get_value(ptr op_ptr, int index) {
  if (!op_ptr) {
    scheme_error("mlir-ir-op-operand-get-value", "operation must not be null");
  }
  mlir::Operation* op = static_cast<mlir::Operation*>(op_ptr);
  if (index < 0 || index >= (int)op->getNumOperands()) {
    scheme_error("mlir-ir-op-operand-get-value",
                 "index out of range: ", (int64_t)index, " (size ",
                 (int64_t)op->getNumOperands(), ")");
  }
  return const_cast<void*>(op->getOperand(index).getAsOpaquePointer());
}

static ptr mlir_ir_op_result_get_value(ptr op_ptr, int index) {
  if (!op_ptr) {
    scheme_error("mlir-ir-op-result-get-value", "operation must not be null");
  }
  mlir::Operation* op = static_cast<mlir::Operation*>(op_ptr);
  if (index < 0 || index >= (int)op->getNumResults()) {
    scheme_error("mlir-ir-op-result-get-value",
                 "index out of range: ", (int64_t)index, " (size ",
                 (int64_t)op->getNumResults(), ")");
  }
  return const_cast<void*>(op->getResult(index).getAsOpaquePointer());
}

static ptr mlir_ir_operation_get_loc(ptr op_ptr) {
  if (!op_ptr) {
    scheme_error("mlir-ir-operation-get-loc", "operation must not be null");
  }
  return const_cast<void*>(
      static_cast<mlir::Operation*>(op_ptr)->getLoc().getAsOpaquePointer());
}

static void mlir_ir_operation_walk(uint64_t op, ptr callback) {
  if (!op) {
    return;
  }
  mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op);
  crest::LockedSchemeObject locked(callback);
  cppOp->walk([&locked](mlir::Operation* walkOp) {
    ptr schemeOp = Sunsigned64(reinterpret_cast<uint64_t>(walkOp));
    Scall1(locked.get(), schemeOp);
  });
}

static void mlir_ir_operation_set_operand(uint64_t op_ptr, int index,
                                          uint64_t value) {
  if (!op_ptr || !value) {
    return;
  }
  mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  mlir::Value val = unwrap(MlirValue{reinterpret_cast<const void*>(value)});
  op->setOperand(static_cast<unsigned>(index), val);
}

static int mlir_ir_operation_use_empty(uint64_t op_ptr) {
  if (!op_ptr) {
    return 1;
  }
  return reinterpret_cast<mlir::Operation*>(op_ptr)->use_empty() ? 1 : 0;
}

const char* mlir_ir_operation_get_string_attr(uint64_t op_ptr,
                                              const char* attr_name) {
  if (!op_ptr) {
    return "";
  }
  auto attr = reinterpret_cast<mlir::Operation*>(op_ptr)
                  ->getAttrOfType<mlir::StringAttr>(attr_name);
  if (!attr) {
    return "";
  }
  return attr.getValue().data();
}

static int64_t mlir_ir_operation_get_integer_attr(uint64_t op_ptr,
                                                  const char* attr_name,
                                                  int64_t default_val) {
  if (!op_ptr) {
    return default_val;
  }
  if (auto attr = reinterpret_cast<mlir::Operation*>(op_ptr)
                      ->getAttrOfType<mlir::IntegerAttr>(attr_name)) {
    return attr.getValue().getSExtValue();
  }
  return default_val;
}

static int mlir_ir_operation_has_attr(uint64_t op_ptr, const char* attr_name) {
  if (!op_ptr) {
    scheme_error("mlir-ir-operation-has-attr", "operation must not be null");
  }
  return reinterpret_cast<mlir::Operation*>(op_ptr)->hasAttr(attr_name) ? 1 : 0;
}

static void mlir_ir_operation_emit_error(uint64_t op_ptr, const char* msg) {
  if (!op_ptr) {
    mlir_support_logging_error(msg);
    return;
  }
  reinterpret_cast<mlir::Operation*>(op_ptr)->emitError(msg);
}

static void mlir_ir_operation_emit_warning(uint64_t op_ptr, const char* msg) {
  if (!op_ptr) {
    mlir_support_logging_warning(msg);
    return;
  }
  reinterpret_cast<mlir::Operation*>(op_ptr)->emitWarning(msg);
}

static void mlir_ir_operation_emit_remark(uint64_t op_ptr, const char* msg) {
  if (!op_ptr) {
    mlir_support_logging_info(msg);
    return;
  }
  reinterpret_cast<mlir::Operation*>(op_ptr)->emitRemark(msg);
}

static void mlir_ir_operation_erase(uint64_t op_ptr) {
  if (!op_ptr) {
    return;
  }
  reinterpret_cast<mlir::Operation*>(op_ptr)->erase();
}

static uint64_t mlir_ir_operation_get_attr(uint64_t op_ptr, const char* name) {
  if (!op_ptr) {
    scheme_error("mlir-ir-operation-get-attr", "operation must not be null");
  }
  if (!name) {
    scheme_error("mlir-ir-operation-get-attr",
                 "attribute name must not be null");
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto attr = op->getAttr(name);
  return attr ? reinterpret_cast<uint64_t>(attr.getAsOpaquePointer()) : 0;
}

static void mlir_ir_operation_set_attr(uint64_t op_ptr, const char* name,
                                       uint64_t attr_ptr) {
  if (!op_ptr || !attr_ptr) {
    return;
  }
  reinterpret_cast<mlir::Operation*>(op_ptr)->setAttr(
      name, mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
}

static double mlir_ir_operation_get_float_attr(uint64_t op_ptr,
                                               const char* name) {
  if (!op_ptr || !name) {
    return std::numeric_limits<double>::quiet_NaN();
  }
  auto attr = reinterpret_cast<mlir::Operation*>(op_ptr)
                  ->getAttrOfType<mlir::FloatAttr>(name);
  return attr ? attr.getValueAsDouble()
              : std::numeric_limits<double>::quiet_NaN();
}

// Get the i-th region of an operation.
// op_ptr:      Operation* as uptr
// region_idx:  0-based region index
// Returns: Region* as uptr; raises a Scheme error if op is null or index out of
// range.
static uint64_t mlir_ir_operation_get_attr_dictionary(uint64_t op_ptr) {
  if (!op_ptr) {
    scheme_error("mlir::Operation::getAttrDictionary", "null op pointer");
  }
  return reinterpret_cast<uint64_t>(reinterpret_cast<mlir::Operation*>(op_ptr)
                                        ->getAttrDictionary()
                                        .getAsOpaquePointer());
}

static void mlir_ir_operation_set_attrs(uint64_t op_ptr, uint64_t dict_ptr) {
  if (!op_ptr) {
    scheme_error("mlir::Operation::setAttrs", "null op pointer");
  }
  if (!dict_ptr) {
    scheme_error("mlir::Operation::setAttrs", "null dict pointer");
  }
  reinterpret_cast<mlir::Operation*>(op_ptr)->setAttrs(
      mlir::DictionaryAttr::getFromOpaquePointer(
          reinterpret_cast<const void*>(dict_ptr)));
}

static uint64_t mlir_ir_operation_get_region(uint64_t op_ptr, int region_idx) {
  if (!op_ptr) {
    scheme_error("mlir-ir-operation-get-region", "operation must not be null");
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  if (region_idx < 0 || region_idx >= (int)op->getNumRegions()) {
    scheme_error("mlir-ir-operation-get-region",
                 "index out of range: ", (int64_t)region_idx, " (size ",
                 (int64_t)op->getNumRegions(), ")");
  }
  return reinterpret_cast<uint64_t>(&op->getRegion(region_idx));
}

} // extern "C"

namespace crest {

void registerIROperationBindings() {
  Sregister_symbol("mlir::Operation::getName",
                   (void*)::mlir_ir_operation_get_name);
  Sregister_symbol("mlir::Operation::getContext",
                   (void*)::mlir_ir_operation_get_context);
  Sregister_symbol("mlir::Operation::getNumOperands",
                   (void*)::mlir_ir_operation_get_num_operands);
  Sregister_symbol("mlir::Operation::getNumResults",
                   (void*)::mlir_ir_operation_get_num_results);
  Sregister_symbol("mlir::Operation::getOpOperand",
                   (void*)::mlir_ir_operation_get_op_operand);
  Sregister_symbol("mlir::Operation::getResult",
                   (void*)::mlir_ir_operation_get_result);
  Sregister_symbol("mlir::Operation::getParentOp",
                   (void*)::mlir_ir_operation_get_parent_op);
  Sregister_symbol("mlir::OpOperand::get",
                   (void*)::mlir_ir_op_operand_get_value);
  Sregister_symbol("mlir::OpResult::getOwner",
                   (void*)::mlir_ir_op_result_get_value);
  Sregister_symbol("mlir::Operation::getLoc",
                   (void*)::mlir_ir_operation_get_loc);
  Sregister_symbol("mlir::Operation::walk", (void*)::mlir_ir_operation_walk);
  Sregister_symbol("mlir::Operation::setOperand",
                   (void*)::mlir_ir_operation_set_operand);
  Sregister_symbol("mlir::Operation::use_empty",
                   (void*)::mlir_ir_operation_use_empty);
  Sregister_symbol("mlir::Operation::getAttrOfType<StringAttr>",
                   (void*)::mlir_ir_operation_get_string_attr);
  Sregister_symbol("mlir::Operation::getAttrOfType<IntegerAttr>",
                   (void*)::mlir_ir_operation_get_integer_attr);
  Sregister_symbol("mlir::Operation::hasAttr",
                   (void*)::mlir_ir_operation_has_attr);
  Sregister_symbol("mlir::Operation::emitError",
                   (void*)::mlir_ir_operation_emit_error);
  Sregister_symbol("mlir::Operation::emitWarning",
                   (void*)::mlir_ir_operation_emit_warning);
  Sregister_symbol("mlir::Operation::emitRemark",
                   (void*)::mlir_ir_operation_emit_remark);
  Sregister_symbol("mlir::Operation::erase", (void*)::mlir_ir_operation_erase);
  Sregister_symbol("mlir::Operation::getAttrDictionary",
                   (void*)::mlir_ir_operation_get_attr_dictionary);
  Sregister_symbol("mlir::Operation::setAttrs",
                   (void*)::mlir_ir_operation_set_attrs);
  Sregister_symbol("mlir::Operation::getRegion",
                   (void*)::mlir_ir_operation_get_region);
  Sregister_symbol("mlir::Operation::getAttr",
                   (void*)::mlir_ir_operation_get_attr);
  Sregister_symbol("mlir::Operation::setAttr",
                   (void*)::mlir_ir_operation_set_attr);
  // Aliases with ? and ! suffix (Scheme predicate/mutator convention)
  Sregister_symbol("mlir::Operation::use_empty?",
                   (void*)::mlir_ir_operation_use_empty);
  Sregister_symbol("mlir::Operation::hasAttr?",
                   (void*)::mlir_ir_operation_has_attr);
  Sregister_symbol("mlir::Operation::setAttr!",
                   (void*)::mlir_ir_operation_set_attr);
  Sregister_symbol("mlir::Operation::emitError!",
                   (void*)::mlir_ir_operation_emit_error);
  Sregister_symbol("mlir::Operation::getAttrOfType<FloatAttr>",
                   (void*)::mlir_ir_operation_get_float_attr);
}

} // namespace crest

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

static void scheme_error(const char* who, const char* msg) {
  Scall2(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring(msg));
}

static void scheme_error_oob(const char* who, int64_t idx, int64_t size) {
  Scall4(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring("index out of range"), Sfixnum(idx), Sfixnum(size));
}

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

uint64_t mlir_ir_operation_get_context(uint64_t op) {
  if (!op) {
    scheme_error("mlir-ir-operation-get-context", "operation must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<uint64_t>(
      reinterpret_cast<mlir::Operation*>(op)->getContext());
}

int64_t mlir_ir_operation_get_num_operands(uint64_t op) {
  if (!op) {
    scheme_error("mlir-ir-operation-get-num-operands",
                 "operation must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<mlir::Operation*>(op)->getNumOperands();
}

int64_t mlir_ir_operation_get_num_results(uint64_t op) {
  if (!op) {
    scheme_error("mlir-ir-operation-get-num-results",
                 "operation must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<mlir::Operation*>(op)->getNumResults();
}

uint64_t mlir_ir_operation_get_op_operand(uint64_t op, int64_t index) {
  if (!op) {
    scheme_error("mlir-ir-operation-get-op-operand",
                 "operation must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op);
  if (index < 0 || index >= (int64_t)cppOp->getNumOperands()) {
    scheme_error_oob("mlir-ir-operation-get-op-operand", index,
                     (int64_t)cppOp->getNumOperands());
    return 0; // unreachable — error performs non-local exit
  }
  mlir::Value val = cppOp->getOperand(index);
  MlirValue cVal = wrap(val);
  return reinterpret_cast<uint64_t>(const_cast<void*>(cVal.ptr));
}

uint64_t mlir_ir_operation_get_result(uint64_t op, int64_t index) {
  if (!op) {
    scheme_error("mlir-ir-operation-get-result", "operation must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op);
  if (index < 0 || index >= (int64_t)cppOp->getNumResults()) {
    scheme_error_oob("mlir-ir-operation-get-result", index,
                     (int64_t)cppOp->getNumResults());
    return 0; // unreachable — error performs non-local exit
  }
  mlir::Value val = cppOp->getResult(index);
  MlirValue cVal = wrap(val);
  return reinterpret_cast<uint64_t>(const_cast<void*>(cVal.ptr));
}

ptr mlir_ir_operation_get_parent_op(ptr op_ptr) {
  if (!op_ptr) {
    scheme_error("mlir-ir-operation-get-parent-op",
                 "operation must not be null");
    return nullptr; // unreachable — error performs non-local exit
  }
  return static_cast<mlir::Operation*>(op_ptr)->getParentOp();
}

ptr mlir_ir_op_operand_get_value(ptr op_ptr, int index) {
  if (!op_ptr) {
    scheme_error("mlir-ir-op-operand-get-value", "operation must not be null");
    return nullptr; // unreachable — error performs non-local exit
  }
  mlir::Operation* op = static_cast<mlir::Operation*>(op_ptr);
  if (index < 0 || index >= (int)op->getNumOperands()) {
    scheme_error_oob("mlir-ir-op-operand-get-value", (int64_t)index,
                     (int64_t)op->getNumOperands());
    return nullptr; // unreachable — error performs non-local exit
  }
  return const_cast<void*>(op->getOperand(index).getAsOpaquePointer());
}

ptr mlir_ir_op_result_get_value(ptr op_ptr, int index) {
  if (!op_ptr) {
    scheme_error("mlir-ir-op-result-get-value", "operation must not be null");
    return nullptr; // unreachable — error performs non-local exit
  }
  mlir::Operation* op = static_cast<mlir::Operation*>(op_ptr);
  if (index < 0 || index >= (int)op->getNumResults()) {
    scheme_error_oob("mlir-ir-op-result-get-value", (int64_t)index,
                     (int64_t)op->getNumResults());
    return nullptr; // unreachable — error performs non-local exit
  }
  return const_cast<void*>(op->getResult(index).getAsOpaquePointer());
}

ptr mlir_ir_operation_get_loc(ptr op_ptr) {
  if (!op_ptr) {
    scheme_error("mlir-ir-operation-get-loc", "operation must not be null");
    return nullptr; // unreachable — error performs non-local exit
  }
  return const_cast<void*>(
      static_cast<mlir::Operation*>(op_ptr)->getLoc().getAsOpaquePointer());
}

void mlir_ir_operation_walk(uint64_t op, ptr callback) {
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

void mlir_ir_operation_set_operand(uint64_t op_ptr, int index, uint64_t value) {
  if (!op_ptr || !value) {
    return;
  }
  mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  mlir::Value val = unwrap(MlirValue{reinterpret_cast<const void*>(value)});
  op->setOperand(static_cast<unsigned>(index), val);
}

int mlir_ir_operation_use_empty(uint64_t op_ptr) {
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

int64_t mlir_ir_operation_get_integer_attr(uint64_t op_ptr,
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

ptr mlir_ir_operation_get_integer_array_attr(uint64_t op_ptr,
                                             const char* attr_name) {
  if (!op_ptr) {
    return Snil;
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  if (auto attr = op->getAttrOfType<mlir::DenseI64ArrayAttr>(attr_name)) {
    ptr list = Snil;
    for (int i = (int)attr.size() - 1; i >= 0; --i) {
      list = Scons(Sinteger(attr[i]), list);
    }
    return list;
  }
  if (auto attr = op->getAttrOfType<mlir::ArrayAttr>(attr_name)) {
    ptr list = Snil;
    for (int i = (int)attr.size() - 1; i >= 0; --i) {
      auto intAttr = mlir::dyn_cast<mlir::IntegerAttr>(attr[i]);
      if (!intAttr) {
        return Snil;
      }
      list = Scons(Sinteger(intAttr.getInt()), list);
    }
    return list;
  }
  return Snil;
}

void mlir_ir_operation_set_index_attr(uint64_t op_ptr, const char* attr_name,
                                      int64_t value) {
  if (!op_ptr) {
    return;
  }
  mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op_ptr);
  cppOp->setAttr(
      attr_name,
      mlir::IntegerAttr::get(mlir::IndexType::get(cppOp->getContext()), value));
}

void mlir_ir_operation_set_i64_array_attr(uint64_t op_ptr,
                                          const char* attr_name,
                                          ptr values_list) {
  if (!op_ptr) {
    return;
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  llvm::SmallVector<mlir::Attribute> attrs;
  auto i64Type = mlir::IntegerType::get(op->getContext(), 64);
  for (ptr cur = static_cast<ptr>(values_list); cur != Snil; cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      break;
    }
    attrs.push_back(mlir::IntegerAttr::get(i64Type, Sinteger_value(Scar(cur))));
  }
  op->setAttr(attr_name, mlir::ArrayAttr::get(op->getContext(), attrs));
}

void mlir_ir_operation_set_dense_i64_array(uint64_t op_ptr,
                                           const char* attr_name,
                                           ptr values_list) {
  if (!op_ptr) {
    return;
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  llvm::SmallVector<int64_t> values;
  for (ptr cur = static_cast<ptr>(values_list); cur != Snil; cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      break;
    }
    values.push_back(Sinteger_value(Scar(cur)));
  }
  op->setAttr(attr_name,
              mlir::DenseI64ArrayAttr::get(op->getContext(), values));
}

void mlir_ir_operation_set_dense_i32_array(uint64_t op_ptr,
                                           const char* attr_name,
                                           ptr values_list) {
  if (!op_ptr) {
    return;
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  llvm::SmallVector<int32_t> values;
  for (ptr cur = static_cast<ptr>(values_list); cur != Snil; cur = Scdr(cur)) {
    if (!Spairp(cur)) {
      break;
    }
    values.push_back(static_cast<int32_t>(Sinteger_value(Scar(cur))));
  }
  op->setAttr(attr_name,
              mlir::DenseI32ArrayAttr::get(op->getContext(), values));
}

void mlir_ir_operation_set_f32_attr(uint64_t op_ptr, const char* name,
                                    double value) {
  if (!op_ptr) {
    return;
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  op->setAttr(name,
              mlir::FloatAttr::get(mlir::Float32Type::get(op->getContext()),
                                   static_cast<float>(value)));
}

void mlir_ir_operation_set_i64_attr(uint64_t op_ptr, const char* name,
                                    int64_t value) {
  if (!op_ptr) {
    return;
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  op->setAttr(name, mlir::IntegerAttr::get(
                        mlir::IntegerType::get(op->getContext(), 64), value));
}

void mlir_ir_operation_set_unit_attr(uint64_t op_ptr, const char* name) {
  if (!op_ptr) {
    return;
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  op->setAttr(name, mlir::UnitAttr::get(op->getContext()));
}

void mlir_ir_operation_copy_attr(uint64_t dst_op_ptr, const char* dst_name,
                                 uint64_t src_op_ptr, const char* src_name) {
  if (!dst_op_ptr || !src_op_ptr) {
    return;
  }
  auto* dst = reinterpret_cast<mlir::Operation*>(dst_op_ptr);
  auto* src = reinterpret_cast<mlir::Operation*>(src_op_ptr);
  auto attr = src->getAttr(src_name);
  if (attr) {
    dst->setAttr(dst_name, attr);
  }
}

int mlir_ir_operation_has_attr(uint64_t op_ptr, const char* attr_name) {
  if (!op_ptr) {
    scheme_error("mlir-ir-operation-has-attr", "operation must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<mlir::Operation*>(op_ptr)->hasAttr(attr_name) ? 1 : 0;
}

void mlir_ir_operation_emit_error(uint64_t op_ptr, const char* msg) {
  if (!op_ptr) {
    mlir_support_logging_error(msg);
    return;
  }
  reinterpret_cast<mlir::Operation*>(op_ptr)->emitError(msg);
}

void mlir_ir_operation_emit_warning(uint64_t op_ptr, const char* msg) {
  if (!op_ptr) {
    mlir_support_logging_warning(msg);
    return;
  }
  reinterpret_cast<mlir::Operation*>(op_ptr)->emitWarning(msg);
}

void mlir_ir_operation_emit_remark(uint64_t op_ptr, const char* msg) {
  if (!op_ptr) {
    mlir_support_logging_info(msg);
    return;
  }
  reinterpret_cast<mlir::Operation*>(op_ptr)->emitRemark(msg);
}

void mlir_ir_operation_erase(uint64_t op_ptr) {
  if (!op_ptr) {
    return;
  }
  reinterpret_cast<mlir::Operation*>(op_ptr)->erase();
}

uint64_t mlir_ir_operation_get_attr(uint64_t op_ptr, const char* name) {
  if (!op_ptr) {
    scheme_error("mlir-ir-operation-get-attr", "operation must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  if (!name) {
    scheme_error("mlir-ir-operation-get-attr",
                 "attribute name must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto attr = op->getAttr(name);
  return attr ? reinterpret_cast<uint64_t>(attr.getAsOpaquePointer()) : 0;
}

void mlir_ir_operation_set_attr(uint64_t op_ptr, const char* name,
                                uint64_t attr_ptr) {
  if (!op_ptr || !attr_ptr) {
    return;
  }
  reinterpret_cast<mlir::Operation*>(op_ptr)->setAttr(
      name, mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
}

double mlir_ir_operation_get_float_attr(uint64_t op_ptr, const char* name) {
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
uint64_t mlir_ir_operation_get_region(uint64_t op_ptr, int region_idx) {
  if (!op_ptr) {
    scheme_error("mlir-ir-operation-get-region", "operation must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  if (region_idx < 0 || region_idx >= (int)op->getNumRegions()) {
    scheme_error_oob("mlir-ir-operation-get-region", (int64_t)region_idx,
                     (int64_t)op->getNumRegions());
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<uint64_t>(&op->getRegion(region_idx));
}

} // extern "C"

namespace crest {

void registerIROperationBindings() {
  Sregister_symbol("mlir_ir_operation_get_name",
                   (void*)::mlir_ir_operation_get_name);
  Sregister_symbol("mlir_ir_operation_get_context",
                   (void*)::mlir_ir_operation_get_context);
  Sregister_symbol("mlir_ir_operation_get_num_operands",
                   (void*)::mlir_ir_operation_get_num_operands);
  Sregister_symbol("mlir_ir_operation_get_num_results",
                   (void*)::mlir_ir_operation_get_num_results);
  Sregister_symbol("mlir_ir_operation_get_op_operand",
                   (void*)::mlir_ir_operation_get_op_operand);
  Sregister_symbol("mlir_ir_operation_get_result",
                   (void*)::mlir_ir_operation_get_result);
  Sregister_symbol("mlir_ir_operation_get_parent_op",
                   (void*)::mlir_ir_operation_get_parent_op);
  Sregister_symbol("mlir_ir_op_operand_get_value",
                   (void*)::mlir_ir_op_operand_get_value);
  Sregister_symbol("mlir_ir_op_result_get_value",
                   (void*)::mlir_ir_op_result_get_value);
  Sregister_symbol("mlir_ir_operation_get_loc",
                   (void*)::mlir_ir_operation_get_loc);
  Sregister_symbol("mlir_ir_operation_walk", (void*)::mlir_ir_operation_walk);
  Sregister_symbol("mlir_ir_operation_set_operand",
                   (void*)::mlir_ir_operation_set_operand);
  Sregister_symbol("mlir_ir_operation_use_empty",
                   (void*)::mlir_ir_operation_use_empty);
  Sregister_symbol("mlir_ir_operation_get_string_attr",
                   (void*)::mlir_ir_operation_get_string_attr);
  Sregister_symbol("mlir_ir_operation_get_integer_attr",
                   (void*)::mlir_ir_operation_get_integer_attr);
  Sregister_symbol("mlir_ir_operation_get_integer_array_attr",
                   (void*)::mlir_ir_operation_get_integer_array_attr);
  Sregister_symbol("mlir_ir_operation_set_f32_attr",
                   (void*)::mlir_ir_operation_set_f32_attr);
  Sregister_symbol("mlir_ir_operation_set_i64_attr",
                   (void*)::mlir_ir_operation_set_i64_attr);
  Sregister_symbol("mlir_ir_operation_set_unit_attr",
                   (void*)::mlir_ir_operation_set_unit_attr);
  Sregister_symbol("mlir_ir_operation_set_index_attr",
                   (void*)::mlir_ir_operation_set_index_attr);
  Sregister_symbol("mlir_ir_operation_set_dense_i64_array",
                   (void*)::mlir_ir_operation_set_dense_i64_array);
  Sregister_symbol("mlir_ir_operation_set_i64_array_attr",
                   (void*)::mlir_ir_operation_set_i64_array_attr);
  Sregister_symbol("mlir_ir_operation_set_dense_i32_array",
                   (void*)::mlir_ir_operation_set_dense_i32_array);
  Sregister_symbol("mlir_ir_operation_copy_attr",
                   (void*)::mlir_ir_operation_copy_attr);
  Sregister_symbol("mlir_ir_operation_has_attr",
                   (void*)::mlir_ir_operation_has_attr);
  Sregister_symbol("mlir_ir_operation_emit_error",
                   (void*)::mlir_ir_operation_emit_error);
  Sregister_symbol("mlir_ir_operation_emit_warning",
                   (void*)::mlir_ir_operation_emit_warning);
  Sregister_symbol("mlir_ir_operation_emit_remark",
                   (void*)::mlir_ir_operation_emit_remark);
  Sregister_symbol("mlir_ir_operation_erase", (void*)::mlir_ir_operation_erase);
  Sregister_symbol("mlir_ir_operation_get_region",
                   (void*)::mlir_ir_operation_get_region);
  Sregister_symbol("mlir_ir_operation_get_attr",
                   (void*)::mlir_ir_operation_get_attr);
  Sregister_symbol("mlir_ir_operation_set_attr",
                   (void*)::mlir_ir_operation_set_attr);
  Sregister_symbol("mlir_ir_operation_get_float_attr",
                   (void*)::mlir_ir_operation_get_float_attr);
  // Backward-compat aliases for old mlir_ir_builtin_attributes_* names
  Sregister_symbol("mlir_ir_builtin_attributes_operation_get_attr",
                   (void*)::mlir_ir_operation_get_attr);
  Sregister_symbol("mlir_ir_builtin_attributes_operation_set_attr",
                   (void*)::mlir_ir_operation_set_attr);
  Sregister_symbol("mlir_ir_builtin_attributes_operation_get_float_attr",
                   (void*)::mlir_ir_operation_get_float_attr);
  // Backward-compat aliases for even older short names
  Sregister_symbol("mlir_operation_get_attribute",
                   (void*)::mlir_ir_operation_get_attr);
  Sregister_symbol("mlir_operation_set_attribute",
                   (void*)::mlir_ir_operation_set_attr);
  Sregister_symbol("mlir_op_get_float_attr",
                   (void*)::mlir_ir_operation_get_float_attr);
}

} // namespace crest

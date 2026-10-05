/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/BuiltinAttributes.h — attribute construction and inspection.
//
// C name convention: mlir_ir_builtin_attributes_<class>_<method>
// Old names are also registered for backward compatibility.

#include "BuiltinAttributes.h"
#include "../Support/ArrayRef.h"
#include "../Support/Logging.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/AsmParser/AsmParser.h"
#include "mlir/IR/AsmState.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Operation.h"
#include <limits>
#include <string>

static void scheme_error(const char* who, const char* msg) {
  Scall2(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring(msg));
}

extern "C" {

//===----------------------------------------------------------------------===//
// Attr construction — mlir_ir_builtin_attributes_*_get
//===----------------------------------------------------------------------===//

uint64_t mlir_ir_builtin_attributes_integer_attr_get_i64(uint64_t ctx_ptr,
                                                         ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(
      mlir::IntegerAttr::get(mlir::IntegerType::get(ctx, 64),
                             Sinteger64_value(value))
          .getAsOpaquePointer());
}

uint64_t mlir_ir_builtin_attributes_integer_attr_get_index(uint64_t ctx_ptr,
                                                           ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(
      mlir::IntegerAttr::get(mlir::IndexType::get(ctx), Sinteger64_value(value))
          .getAsOpaquePointer());
}

uint64_t mlir_ir_builtin_attributes_float_attr_get_f32(uint64_t ctx_ptr,
                                                       ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(
      mlir::FloatAttr::get(mlir::Float32Type::get(ctx),
                           static_cast<float>(Sflonum_value(value)))
          .getAsOpaquePointer());
}

uint64_t mlir_ir_builtin_attributes_dense_i32_array_attr_get(uint64_t ctx_ptr,
                                                             ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  llvm::SmallVector<int32_t> vec;
  for (ptr cur = value; cur != Snil; cur = Scdr(cur)) {
    vec.push_back(static_cast<int32_t>(Sfixnum_value(Scar(cur))));
  }
  return reinterpret_cast<uint64_t>(
      mlir::DenseI32ArrayAttr::get(ctx, vec).getAsOpaquePointer());
}

uint64_t mlir_ir_builtin_attributes_dense_i64_array_attr_get(uint64_t ctx_ptr,
                                                             ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  llvm::SmallVector<int64_t> vec;
  for (ptr cur = value; cur != Snil; cur = Scdr(cur)) {
    vec.push_back(Sinteger64_value(Scar(cur)));
  }
  return reinterpret_cast<uint64_t>(
      mlir::DenseI64ArrayAttr::get(ctx, vec).getAsOpaquePointer());
}

uint64_t mlir_ir_builtin_attributes_parse(uint64_t ctx_ptr, ptr value) {
  if (!Sstringp(value)) {
    scheme_error("mlir-ir-builtin-attributes-parse",
                 "value must be a string (MLIR attribute syntax)");
  }
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  iptr len = Sstring_length(value);
  std::string spec;
  spec.reserve(static_cast<size_t>(len));
  for (iptr i = 0; i < len; ++i) {
    spec.push_back(static_cast<char>(Sstring_ref(value, i)));
  }
  mlir::Attribute attr = mlir::parseAttribute(spec, ctx);
  if (!attr) {
    scheme_error("mlir-ir-builtin-attributes-parse",
                 ("failed to parse attribute: " + spec).c_str());
  }
  return reinterpret_cast<uint64_t>(attr.getAsOpaquePointer());
}

static std::string schemeStringToStd(ptr s) {
  iptr len = Sstring_length(s);
  std::string result(static_cast<size_t>(len), '\0');
  for (iptr i = 0; i < len; ++i) {
    result[i] = static_cast<char>(Sstring_ref(s, i));
  }
  return result;
}

uint64_t mlir_ir_builtin_attributes_dense_resource_elements_attr_get(
    uint64_t /*ctx_ptr*/, ptr value) {
  auto result_type_ptr = Sunsigned64_value(Scar(value));
  std::string key_str = schemeStringToStd(Scar(Scdr(value)));
  int64_t data_addr = Sinteger64_value(Scar(Scdr(Scdr(value))));
  int64_t data_size = Sinteger64_value(Scar(Scdr(Scdr(Scdr(value)))));
  auto baseType = mlir::Type::getFromOpaquePointer(
      reinterpret_cast<const void*>(result_type_ptr));
  auto resultType = llvm::dyn_cast<mlir::RankedTensorType>(baseType);
  if (!resultType) {
    scheme_error("mlir-ir-builtin-attributes-dense-resource-elements-attr-get",
                 "result-type is not a RankedTensorType");
  }
  llvm::ArrayRef<char> data = {
      reinterpret_cast<const char*>(static_cast<uintptr_t>(data_addr)),
      static_cast<size_t>(data_size)};
  return reinterpret_cast<uint64_t>(
      mlir::DenseResourceElementsAttr::get(
          resultType, key_str.c_str(),
          mlir::UnmanagedAsmResourceBlob::allocateInferAlign(data))
          .getAsOpaquePointer());
}

//===----------------------------------------------------------------------===//
// mlir_attr_isa_* — kept under old prefix; these are discovered via
// foreign-entry? dispatch in (mlir core attribute). New canonical names also
// registered.
//===----------------------------------------------------------------------===//

int mlir_ir_builtin_attributes_integer_attr_isa(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  return mlir::isa<mlir::IntegerAttr>(mlir::Attribute::getFromOpaquePointer(
             reinterpret_cast<const void*>(attr_ptr)))
             ? 1
             : 0;
}

int mlir_ir_builtin_attributes_float_attr_isa(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  return mlir::isa<mlir::FloatAttr>(mlir::Attribute::getFromOpaquePointer(
             reinterpret_cast<const void*>(attr_ptr)))
             ? 1
             : 0;
}

int mlir_ir_builtin_attributes_string_attr_isa(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  return mlir::isa<mlir::StringAttr>(mlir::Attribute::getFromOpaquePointer(
             reinterpret_cast<const void*>(attr_ptr)))
             ? 1
             : 0;
}

int mlir_ir_builtin_attributes_dense_i32_array_attr_isa(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  return mlir::isa<mlir::DenseI32ArrayAttr>(
             mlir::Attribute::getFromOpaquePointer(
                 reinterpret_cast<const void*>(attr_ptr)))
             ? 1
             : 0;
}

int mlir_ir_builtin_attributes_dense_elements_attr_isa(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  return mlir::isa<mlir::DenseElementsAttr>(
             mlir::Attribute::getFromOpaquePointer(
                 reinterpret_cast<const void*>(attr_ptr)))
             ? 1
             : 0;
}

int mlir_ir_builtin_attributes_dense_elements_attr_is_splat(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  auto dense = mlir::dyn_cast<mlir::DenseElementsAttr>(attr);
  return (dense && dense.isSplat()) ? 1 : 0;
}

int mlir_ir_builtin_attributes_float32_attr_isa(uint64_t attr_ptr) {
  return mlir_ir_builtin_attributes_float_attr_isa(attr_ptr);
}

//===----------------------------------------------------------------------===//
// mlir_attr_as_* — extraction
//===----------------------------------------------------------------------===//

ptr mlir_ir_builtin_attributes_integer_attr_get_value(uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error("mlir-ir-builtin-attributes-integer-attr-get-value",
                 "null attribute pointer");
  }
  auto iattr =
      mlir::dyn_cast<mlir::IntegerAttr>(mlir::Attribute::getFromOpaquePointer(
          reinterpret_cast<const void*>(attr_ptr)));
  if (!iattr) {
    scheme_error("mlir-ir-builtin-attributes-integer-attr-get-value",
                 "attribute is not an IntegerAttr");
  }
  return Sinteger64(iattr.getValue().getSExtValue());
}

ptr mlir_ir_builtin_attributes_float_attr_get_value(uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error("mlir-ir-builtin-attributes-float-attr-get-value",
                 "null attribute pointer");
  }
  auto fattr =
      mlir::dyn_cast<mlir::FloatAttr>(mlir::Attribute::getFromOpaquePointer(
          reinterpret_cast<const void*>(attr_ptr)));
  if (!fattr) {
    scheme_error("mlir-ir-builtin-attributes-float-attr-get-value",
                 "attribute is not a FloatAttr");
  }
  return Sflonum(fattr.getValueAsDouble());
}

ptr mlir_ir_builtin_attributes_float32_attr_get_value(uint64_t attr_ptr) {
  return mlir_ir_builtin_attributes_float_attr_get_value(attr_ptr);
}

uint64_t mlir_ir_builtin_attributes_dense_i32_array_attr_as_array_ref(
    uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error("mlir-ir-builtin-attributes-dense-i32-array-attr-as-array-ref",
                 "null attribute pointer");
  }
  auto arr = mlir::dyn_cast<mlir::DenseI32ArrayAttr>(
      mlir::Attribute::getFromOpaquePointer(
          reinterpret_cast<const void*>(attr_ptr)));
  if (!arr) {
    scheme_error("mlir-ir-builtin-attributes-dense-i32-array-attr-as-array-ref",
                 "attribute is not a DenseI32ArrayAttr");
  }
  auto* ref = new CArrayRef{reinterpret_cast<uint64_t>(arr.asArrayRef().data()),
                            static_cast<uint64_t>(arr.size())};
  return reinterpret_cast<uint64_t>(ref);
}

//===----------------------------------------------------------------------===//
// mlir_attr_into_* — complex extraction
//===----------------------------------------------------------------------===//

ptr mlir_ir_builtin_attributes_dense_fp_elements_attr_splat_value(
    uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error(
        "mlir-ir-builtin-attributes-dense-fp-elements-attr-splat-value",
        "null attribute pointer");
  }
  auto dense = mlir::dyn_cast<mlir::DenseFPElementsAttr>(
      mlir::Attribute::getFromOpaquePointer(
          reinterpret_cast<const void*>(attr_ptr)));
  if (!dense) {
    scheme_error(
        "mlir-ir-builtin-attributes-dense-fp-elements-attr-splat-value",
        "attribute is not a DenseFPElementsAttr");
  }
  if (!dense.isSplat()) {
    scheme_error(
        "mlir-ir-builtin-attributes-dense-fp-elements-attr-splat-value",
        "DenseFPElementsAttr is not a splat");
  }
  return Sflonum((*dense.begin()).convertToDouble());
}

ptr mlir_ir_builtin_attributes_dense_int_elements_attr_splat_value(
    uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error(
        "mlir-ir-builtin-attributes-dense-int-elements-attr-splat-value",
        "null attribute pointer");
  }
  auto dense = mlir::dyn_cast<mlir::DenseIntElementsAttr>(
      mlir::Attribute::getFromOpaquePointer(
          reinterpret_cast<const void*>(attr_ptr)));
  if (!dense) {
    scheme_error(
        "mlir-ir-builtin-attributes-dense-int-elements-attr-splat-value",
        "attribute is not a DenseIntElementsAttr");
  }
  if (!dense.isSplat()) {
    scheme_error(
        "mlir-ir-builtin-attributes-dense-int-elements-attr-splat-value",
        "DenseIntElementsAttr is not a splat");
  }
  return Sinteger64((*dense.begin()).getSExtValue());
}

ptr mlir_ir_builtin_attributes_dense_i32_array_attr_to_list(uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error("mlir-ir-builtin-attributes-dense-i32-array-attr-to-list",
                 "null attribute pointer");
  }
  auto arr = mlir::dyn_cast<mlir::DenseI32ArrayAttr>(
      mlir::Attribute::getFromOpaquePointer(
          reinterpret_cast<const void*>(attr_ptr)));
  if (!arr) {
    scheme_error("mlir-ir-builtin-attributes-dense-i32-array-attr-to-list",
                 "attribute is not a DenseI32ArrayAttr");
  }
  ptr result = Snil;
  auto vals = arr.asArrayRef();
  for (int i = static_cast<int>(vals.size()) - 1; i >= 0; --i) {
    result = Scons(Sfixnum(vals[i]), result);
  }
  return result;
}

//===----------------------------------------------------------------------===//
// Misplaced (TODO: move to IR/Operation and IR/BuiltinTypes in later PRs)
//===----------------------------------------------------------------------===//

uint64_t mlir_ir_builtin_attributes_operation_get_attr(uint64_t op_ptr,
                                                       const char* name) {
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto attr = op->getAttr(name);
  return attr ? reinterpret_cast<uint64_t>(attr.getAsOpaquePointer()) : 0;
}

void mlir_ir_builtin_attributes_operation_set_attr(uint64_t op_ptr,
                                                   const char* name,
                                                   uint64_t attr_ptr) {
  reinterpret_cast<mlir::Operation*>(op_ptr)->setAttr(
      name, mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
}

double mlir_ir_builtin_attributes_operation_get_float_attr(uint64_t op_ptr,
                                                           const char* name) {
  if (!op_ptr || !name) {
    return std::numeric_limits<double>::quiet_NaN();
  }
  auto attr = reinterpret_cast<mlir::Operation*>(op_ptr)
                  ->getAttrOfType<mlir::FloatAttr>(name);
  return attr ? attr.getValueAsDouble()
              : std::numeric_limits<double>::quiet_NaN();
}

// Kept for backward compat — duplicate of dense_elements_attr_is_splat.
int mlir_attr_splat_int_value_compat(uint64_t attr_ptr, int64_t absent_val) {
  if (!attr_ptr) {
    return static_cast<int>(absent_val);
  }
  auto dense = mlir::dyn_cast<mlir::DenseIntElementsAttr>(
      mlir::Attribute::getFromOpaquePointer(
          reinterpret_cast<const void*>(attr_ptr)));
  if (!dense || !dense.isSplat()) {
    return static_cast<int>(absent_val);
  }
  return static_cast<int>((*dense.begin()).getSExtValue());
}

} // extern "C"

namespace crest {

void registerIRBuiltinAttributesBindings() {
  // ── New canonical names ──────────────────────────────────────────────────
  Sregister_symbol("mlir_ir_builtin_attributes_integer_attr_get_i64",
                   (void*)::mlir_ir_builtin_attributes_integer_attr_get_i64);
  Sregister_symbol("mlir_ir_builtin_attributes_integer_attr_get_index",
                   (void*)::mlir_ir_builtin_attributes_integer_attr_get_index);
  Sregister_symbol("mlir_ir_builtin_attributes_float_attr_get_f32",
                   (void*)::mlir_ir_builtin_attributes_float_attr_get_f32);
  Sregister_symbol(
      "mlir_ir_builtin_attributes_dense_i32_array_attr_get",
      (void*)::mlir_ir_builtin_attributes_dense_i32_array_attr_get);
  Sregister_symbol(
      "mlir_ir_builtin_attributes_dense_i64_array_attr_get",
      (void*)::mlir_ir_builtin_attributes_dense_i64_array_attr_get);
  Sregister_symbol("mlir_ir_builtin_attributes_parse",
                   (void*)::mlir_ir_builtin_attributes_parse);
  Sregister_symbol(
      "mlir_ir_builtin_attributes_dense_resource_elements_attr_get",
      (void*)::mlir_ir_builtin_attributes_dense_resource_elements_attr_get);
  Sregister_symbol("mlir_ir_builtin_attributes_integer_attr_isa",
                   (void*)::mlir_ir_builtin_attributes_integer_attr_isa);
  Sregister_symbol("mlir_ir_builtin_attributes_float_attr_isa",
                   (void*)::mlir_ir_builtin_attributes_float_attr_isa);
  Sregister_symbol("mlir_ir_builtin_attributes_string_attr_isa",
                   (void*)::mlir_ir_builtin_attributes_string_attr_isa);
  Sregister_symbol(
      "mlir_ir_builtin_attributes_dense_i32_array_attr_isa",
      (void*)::mlir_ir_builtin_attributes_dense_i32_array_attr_isa);
  Sregister_symbol("mlir_ir_builtin_attributes_dense_elements_attr_isa",
                   (void*)::mlir_ir_builtin_attributes_dense_elements_attr_isa);
  Sregister_symbol(
      "mlir_ir_builtin_attributes_dense_elements_attr_is_splat",
      (void*)::mlir_ir_builtin_attributes_dense_elements_attr_is_splat);
  Sregister_symbol("mlir_ir_builtin_attributes_float32_attr_isa",
                   (void*)::mlir_ir_builtin_attributes_float32_attr_isa);
  Sregister_symbol("mlir_ir_builtin_attributes_integer_attr_get_value",
                   (void*)::mlir_ir_builtin_attributes_integer_attr_get_value);
  Sregister_symbol("mlir_ir_builtin_attributes_float_attr_get_value",
                   (void*)::mlir_ir_builtin_attributes_float_attr_get_value);
  Sregister_symbol("mlir_ir_builtin_attributes_float32_attr_get_value",
                   (void*)::mlir_ir_builtin_attributes_float32_attr_get_value);
  Sregister_symbol(
      "mlir_ir_builtin_attributes_dense_i32_array_attr_as_array_ref",
      (void*)::mlir_ir_builtin_attributes_dense_i32_array_attr_as_array_ref);
  Sregister_symbol(
      "mlir_ir_builtin_attributes_dense_fp_elements_attr_splat_value",
      (void*)::mlir_ir_builtin_attributes_dense_fp_elements_attr_splat_value);
  Sregister_symbol(
      "mlir_ir_builtin_attributes_dense_int_elements_attr_splat_value",
      (void*)::mlir_ir_builtin_attributes_dense_int_elements_attr_splat_value);
  Sregister_symbol(
      "mlir_ir_builtin_attributes_dense_i32_array_attr_to_list",
      (void*)::mlir_ir_builtin_attributes_dense_i32_array_attr_to_list);
  Sregister_symbol("mlir_ir_builtin_attributes_operation_get_attr",
                   (void*)::mlir_ir_builtin_attributes_operation_get_attr);
  Sregister_symbol("mlir_ir_builtin_attributes_operation_set_attr",
                   (void*)::mlir_ir_builtin_attributes_operation_set_attr);
  Sregister_symbol(
      "mlir_ir_builtin_attributes_operation_get_float_attr",
      (void*)::mlir_ir_builtin_attributes_operation_get_float_attr);
  // ── Old names (backward compat) — used by generic dispatch in Scheme ─────
  Sregister_symbol("mlir_make_attr_i64",
                   (void*)::mlir_ir_builtin_attributes_integer_attr_get_i64);
  Sregister_symbol("mlir_make_attr_f32",
                   (void*)::mlir_ir_builtin_attributes_float_attr_get_f32);
  Sregister_symbol("mlir_make_attr_index",
                   (void*)::mlir_ir_builtin_attributes_integer_attr_get_index);
  Sregister_symbol(
      "mlir_make_attr_i32_array",
      (void*)::mlir_ir_builtin_attributes_dense_i32_array_attr_get);
  Sregister_symbol(
      "mlir_make_attr_i64_array",
      (void*)::mlir_ir_builtin_attributes_dense_i64_array_attr_get);
  Sregister_symbol("mlir_make_attr_opaque",
                   (void*)::mlir_ir_builtin_attributes_parse);
  Sregister_symbol(
      "mlir_make_attr_dense_resource",
      (void*)::mlir_ir_builtin_attributes_dense_resource_elements_attr_get);
  Sregister_symbol("mlir_operation_get_attribute",
                   (void*)::mlir_ir_builtin_attributes_operation_get_attr);
  Sregister_symbol("mlir_operation_set_attribute",
                   (void*)::mlir_ir_builtin_attributes_operation_set_attr);
  Sregister_symbol(
      "mlir_op_get_float_attr",
      (void*)::mlir_ir_builtin_attributes_operation_get_float_attr);
  Sregister_symbol("mlir_attr_isa_integer",
                   (void*)::mlir_ir_builtin_attributes_integer_attr_isa);
  Sregister_symbol("mlir_attr_isa_float",
                   (void*)::mlir_ir_builtin_attributes_float_attr_isa);
  Sregister_symbol("mlir_attr_isa_string",
                   (void*)::mlir_ir_builtin_attributes_string_attr_isa);
  Sregister_symbol(
      "mlir_attr_isa_array_ref_i32",
      (void*)::mlir_ir_builtin_attributes_dense_i32_array_attr_isa);
  Sregister_symbol("mlir_attr_isa_dense_elements",
                   (void*)::mlir_ir_builtin_attributes_dense_elements_attr_isa);
  Sregister_symbol(
      "mlir_attr_isa_dense_elements_splat",
      (void*)::mlir_ir_builtin_attributes_dense_elements_attr_is_splat);
  Sregister_symbol("mlir_attr_isa_f32",
                   (void*)::mlir_ir_builtin_attributes_float32_attr_isa);
  Sregister_symbol("mlir_attr_as_integer",
                   (void*)::mlir_ir_builtin_attributes_integer_attr_get_value);
  Sregister_symbol("mlir_attr_as_float",
                   (void*)::mlir_ir_builtin_attributes_float_attr_get_value);
  Sregister_symbol("mlir_attr_as_f32",
                   (void*)::mlir_ir_builtin_attributes_float32_attr_get_value);
  Sregister_symbol(
      "mlir_attr_as_array_ref_i32",
      (void*)::mlir_ir_builtin_attributes_dense_i32_array_attr_as_array_ref);
  Sregister_symbol(
      "mlir_attr_into_splat_float",
      (void*)::mlir_ir_builtin_attributes_dense_fp_elements_attr_splat_value);
  Sregister_symbol(
      "mlir_attr_into_splat_integer",
      (void*)::mlir_ir_builtin_attributes_dense_int_elements_attr_splat_value);
  Sregister_symbol(
      "mlir_attr_into_i32_array",
      (void*)::mlir_ir_builtin_attributes_dense_i32_array_attr_to_list);
  // Duplicates removed: mlir_attr_is_splat, mlir_attr_splat_float_value
  // mlir_attr_splat_int_value kept as a differently-signatured compat entry
  Sregister_symbol("mlir_attr_splat_int_value",
                   (void*)::mlir_attr_splat_int_value_compat);
}

} // namespace crest

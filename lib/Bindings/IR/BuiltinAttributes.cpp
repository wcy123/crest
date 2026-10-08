/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/BuiltinAttributes.h — attribute construction and inspection.
//
// C name convention: mlir_ir_builtin_attributes_<class>_<method>

#include "BuiltinAttributes.h"
#include "../Support/ArrayRef.h"
#include "../Support/Logging.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/AsmParser/AsmParser.h"
#include "mlir/IR/AsmState.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include <limits>
#include <string>

extern "C" {

//===----------------------------------------------------------------------===//
// Attr construction — mlir_ir_builtin_attributes_*_get
//===----------------------------------------------------------------------===//

static uint64_t
mlir_ir_builtin_attributes_integer_attr_get_i64(uint64_t ctx_ptr, ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(
      mlir::IntegerAttr::get(mlir::IntegerType::get(ctx, 64),
                             Sinteger64_value(value))
          .getAsOpaquePointer());
}

static uint64_t
mlir_ir_builtin_attributes_integer_attr_get_index(uint64_t ctx_ptr, ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(
      mlir::IntegerAttr::get(mlir::IndexType::get(ctx), Sinteger64_value(value))
          .getAsOpaquePointer());
}

static uint64_t mlir_ir_builtin_attributes_float_attr_get_f32(uint64_t ctx_ptr,
                                                              ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(
      mlir::FloatAttr::get(mlir::Float32Type::get(ctx),
                           static_cast<float>(Sflonum_value(value)))
          .getAsOpaquePointer());
}

static uint64_t
mlir_ir_builtin_attributes_dense_i32_array_attr_get(uint64_t ctx_ptr,
                                                    ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  llvm::SmallVector<int32_t> vec;
  for (ptr cur = value; cur != Snil; cur = Scdr(cur)) {
    vec.push_back(static_cast<int32_t>(Sfixnum_value(Scar(cur))));
  }
  return reinterpret_cast<uint64_t>(
      mlir::DenseI32ArrayAttr::get(ctx, vec).getAsOpaquePointer());
}

static uint64_t
mlir_ir_builtin_attributes_dense_i64_array_attr_get(uint64_t ctx_ptr,
                                                    ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  llvm::SmallVector<int64_t> vec;
  for (ptr cur = value; cur != Snil; cur = Scdr(cur)) {
    vec.push_back(Sinteger64_value(Scar(cur)));
  }
  return reinterpret_cast<uint64_t>(
      mlir::DenseI64ArrayAttr::get(ctx, vec).getAsOpaquePointer());
}

static uint64_t mlir_ir_builtin_attributes_parse(uint64_t ctx_ptr,
                                                 const char* spec) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  mlir::Attribute attr = mlir::parseAttribute(spec, ctx);
  if (!attr) {
    scheme_error("mlir::parseAttribute", "failed to parse attribute: ", spec);
    return 0; // unreachable
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

static uint64_t mlir_ir_builtin_attributes_dense_resource_elements_attr_get(
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
// Attribute type predicates — mlir_ir_builtin_attributes_*_isa
//===----------------------------------------------------------------------===//

static int mlir_ir_builtin_attributes_integer_attr_isa(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  return mlir::isa<mlir::IntegerAttr>(mlir::Attribute::getFromOpaquePointer(
             reinterpret_cast<const void*>(attr_ptr)))
             ? 1
             : 0;
}

static int mlir_ir_builtin_attributes_float_attr_isa(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  return mlir::isa<mlir::FloatAttr>(mlir::Attribute::getFromOpaquePointer(
             reinterpret_cast<const void*>(attr_ptr)))
             ? 1
             : 0;
}

static int mlir_ir_builtin_attributes_string_attr_isa(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  return mlir::isa<mlir::StringAttr>(mlir::Attribute::getFromOpaquePointer(
             reinterpret_cast<const void*>(attr_ptr)))
             ? 1
             : 0;
}

static int
mlir_ir_builtin_attributes_dense_i32_array_attr_isa(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  return mlir::isa<mlir::DenseI32ArrayAttr>(
             mlir::Attribute::getFromOpaquePointer(
                 reinterpret_cast<const void*>(attr_ptr)))
             ? 1
             : 0;
}

static int
mlir_ir_builtin_attributes_dense_elements_attr_isa(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  return mlir::isa<mlir::DenseElementsAttr>(
             mlir::Attribute::getFromOpaquePointer(
                 reinterpret_cast<const void*>(attr_ptr)))
             ? 1
             : 0;
}

static int
mlir_ir_builtin_attributes_dense_elements_attr_is_splat(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  auto dense = mlir::dyn_cast<mlir::DenseElementsAttr>(attr);
  return (dense && dense.isSplat()) ? 1 : 0;
}

static int mlir_ir_builtin_attributes_float32_attr_isa(uint64_t attr_ptr) {
  return mlir_ir_builtin_attributes_float_attr_isa(attr_ptr);
}

//===----------------------------------------------------------------------===//
// Scalar extraction — mlir_ir_builtin_attributes_*_get_value
//===----------------------------------------------------------------------===//

static ptr
mlir_ir_builtin_attributes_integer_attr_get_value(uint64_t attr_ptr) {
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

static ptr mlir_ir_builtin_attributes_float_attr_get_value(uint64_t attr_ptr) {
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

static ptr
mlir_ir_builtin_attributes_float32_attr_get_value(uint64_t attr_ptr) {
  return mlir_ir_builtin_attributes_float_attr_get_value(attr_ptr);
}

static uint64_t mlir_ir_builtin_attributes_dense_i32_array_attr_as_array_ref(
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

static uint64_t mlir_ir_dense_i64_array_as_array_ref(uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error("mlir::DenseI64ArrayAttr::intoArrayRef",
                 "null attribute pointer");
  }
  auto arr = mlir::dyn_cast<mlir::DenseI64ArrayAttr>(
      mlir::Attribute::getFromOpaquePointer(
          reinterpret_cast<const void*>(attr_ptr)));
  if (!arr) {
    scheme_error("mlir::DenseI64ArrayAttr::intoArrayRef",
                 "attribute is not a DenseI64ArrayAttr");
  }
  auto* ref = new CArrayRef{reinterpret_cast<uint64_t>(arr.asArrayRef().data()),
                            static_cast<uint64_t>(arr.size())};
  return reinterpret_cast<uint64_t>(ref);
}

//===----------------------------------------------------------------------===//
// Complex extraction — mlir_ir_builtin_attributes_dense_*_splat_value
//===----------------------------------------------------------------------===//

static ptr mlir_ir_builtin_attributes_dense_fp_elements_attr_splat_value(
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

static ptr mlir_ir_builtin_attributes_dense_int_elements_attr_splat_value(
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

static ptr
mlir_ir_builtin_attributes_dense_i32_array_attr_to_list(uint64_t attr_ptr) {
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

static uint64_t mlir_ir_builtin_attributes_unit_attr_get(uint64_t ctx_ptr) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(
      mlir::UnitAttr::get(ctx).getAsOpaquePointer());
}

} // extern "C"

namespace crest {

void registerIRBuiltinAttributesBindings() {
  // ── C++ naming convention: mlir::ClassName::methodName[<Specialization>] ─
  Sregister_symbol("mlir::IntegerAttr::get<i64>",
                   (void*)::mlir_ir_builtin_attributes_integer_attr_get_i64);
  Sregister_symbol("mlir::IntegerAttr::get<index>",
                   (void*)::mlir_ir_builtin_attributes_integer_attr_get_index);
  Sregister_symbol("mlir::FloatAttr::get<f32>",
                   (void*)::mlir_ir_builtin_attributes_float_attr_get_f32);
  Sregister_symbol(
      "mlir::DenseI32ArrayAttr::get",
      (void*)::mlir_ir_builtin_attributes_dense_i32_array_attr_get);
  Sregister_symbol(
      "mlir::DenseI64ArrayAttr::get",
      (void*)::mlir_ir_builtin_attributes_dense_i64_array_attr_get);
  Sregister_symbol("mlir::parseAttribute",
                   (void*)::mlir_ir_builtin_attributes_parse);
  Sregister_symbol(
      "mlir::DenseResourceElementsAttr::get",
      (void*)::mlir_ir_builtin_attributes_dense_resource_elements_attr_get);
  Sregister_symbol("mlir::isa<IntegerAttr>",
                   (void*)::mlir_ir_builtin_attributes_integer_attr_isa);
  Sregister_symbol("mlir::isa<FloatAttr>",
                   (void*)::mlir_ir_builtin_attributes_float_attr_isa);
  Sregister_symbol("mlir::isa<StringAttr>",
                   (void*)::mlir_ir_builtin_attributes_string_attr_isa);
  Sregister_symbol(
      "mlir::isa<DenseI32ArrayAttr>",
      (void*)::mlir_ir_builtin_attributes_dense_i32_array_attr_isa);
  Sregister_symbol("mlir::isa<DenseElementsAttr>",
                   (void*)::mlir_ir_builtin_attributes_dense_elements_attr_isa);
  Sregister_symbol(
      "mlir::DenseElementsAttr::isSplat",
      (void*)::mlir_ir_builtin_attributes_dense_elements_attr_is_splat);
  Sregister_symbol("mlir::isa<FloatAttr>.f32",
                   (void*)::mlir_ir_builtin_attributes_float32_attr_isa);
  Sregister_symbol("mlir::IntegerAttr::getValue",
                   (void*)::mlir_ir_builtin_attributes_integer_attr_get_value);
  Sregister_symbol("mlir::FloatAttr::getValueAsDouble",
                   (void*)::mlir_ir_builtin_attributes_float_attr_get_value);
  Sregister_symbol("mlir::FloatAttr::getValueAsDouble.f32",
                   (void*)::mlir_ir_builtin_attributes_float32_attr_get_value);
  Sregister_symbol("mlir::DenseI64ArrayAttr::intoArrayRef",
                   (void*)::mlir_ir_dense_i64_array_as_array_ref);
  Sregister_symbol(
      "mlir::DenseI32ArrayAttr::intoArrayRef",
      (void*)::mlir_ir_builtin_attributes_dense_i32_array_attr_as_array_ref);
  Sregister_symbol(
      "mlir::DenseElementsAttr::getSplatValue<APFloat>",
      (void*)::mlir_ir_builtin_attributes_dense_fp_elements_attr_splat_value);
  Sregister_symbol(
      "mlir::DenseElementsAttr::getSplatValue<APInt>",
      (void*)::mlir_ir_builtin_attributes_dense_int_elements_attr_splat_value);
  Sregister_symbol(
      "mlir::DenseI32ArrayAttr::intoArrayRef->list",
      (void*)::mlir_ir_builtin_attributes_dense_i32_array_attr_to_list);
  Sregister_symbol("mlir::UnitAttr::get",
                   (void*)::mlir_ir_builtin_attributes_unit_attr_get);
  // Old-name aliases removed: (mlir core attribute) dynamic dispatch deleted.
}

} // namespace crest

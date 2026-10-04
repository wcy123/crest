/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors (mlir core attribute): attribute construction and op-level get/set.
//
// Family conventions:
//   mlir_make_attr_*   (uint64_t ctx, ptr value) → uint64_t (attr uptr)
//   mlir_attr_isa_*    (uint64_t attr)            → int (0/1)
//   mlir_attr_as_*     (uint64_t attr)            → ptr (boxed Scheme value)
//   mlir_attr_into_*   (uint64_t attr)            → ptr (boxed Scheme value,
//   complex)
//
// All families share a uniform per-family signature so Scheme can discover
// them dynamically via foreign-entry? without hard-coding the list.
//
// Error policy: functions that cannot return a meaningful value signal a
// Scheme error via Scall_error rather than returning a silent sentinel.

#include "../Logging.h"
#include "../SchemeWrapper.h"
#include "../Support/ArrayRef.h"
#include "mlir/AsmParser/AsmParser.h"
#include "mlir/IR/AsmState.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Operation.h"
#include <limits>
#include <string>

// Raise a Scheme error with who + message; does not return.
static void scheme_error(const char* who, const char* msg) {
  Scall2(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring(msg));
}

extern "C" {

//===----------------------------------------------------------------------===//
// mlir_make_attr_* family: (uint64_t ctx, ptr value) → uint64_t attr uptr
//===----------------------------------------------------------------------===//

uint64_t mlir_make_attr_i64(uint64_t ctx_ptr, ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(
      mlir::IntegerAttr::get(mlir::IntegerType::get(ctx, 64),
                             Sinteger64_value(value))
          .getAsOpaquePointer());
}

uint64_t mlir_make_attr_index(uint64_t ctx_ptr, ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(
      mlir::IntegerAttr::get(mlir::IndexType::get(ctx), Sinteger64_value(value))
          .getAsOpaquePointer());
}

uint64_t mlir_make_attr_f32(uint64_t ctx_ptr, ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(
      mlir::FloatAttr::get(mlir::Float32Type::get(ctx),
                           static_cast<float>(Sflonum_value(value)))
          .getAsOpaquePointer());
}

uint64_t mlir_make_attr_i32_array(uint64_t ctx_ptr, ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  llvm::SmallVector<int32_t> vec;
  for (ptr cur = value; cur != Snil; cur = Scdr(cur)) {
    vec.push_back(static_cast<int32_t>(Sfixnum_value(Scar(cur))));
  }
  return reinterpret_cast<uint64_t>(
      mlir::DenseI32ArrayAttr::get(ctx, vec).getAsOpaquePointer());
}

uint64_t mlir_make_attr_i64_array(uint64_t ctx_ptr, ptr value) {
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  llvm::SmallVector<int64_t> vec;
  for (ptr cur = value; cur != Snil; cur = Scdr(cur)) {
    vec.push_back(Sinteger64_value(Scar(cur)));
  }
  return reinterpret_cast<uint64_t>(
      mlir::DenseI64ArrayAttr::get(ctx, vec).getAsOpaquePointer());
}

// Parse an MLIR attribute from its text representation.
// ctx_ptr: MLIRContext* as uptr
// value:   Scheme string — MLIR attribute syntax, e.g. "#hipsr.mem<device>"
//   Without the dialect loaded → OpaqueAttr (same mechanism as !hip.context →
//   OpaqueType) With the dialect loaded → real dialect-specific C++ attr object
//   (automatic)
// Returns: Attribute opaque uptr, or 0 if parsing fails.
uint64_t mlir_make_attr_opaque(uint64_t ctx_ptr, ptr value) {
  if (!Sstringp(value)) {
    scheme_error("mlir-make-attr :opaque",
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
    scheme_error("mlir-make-attr :opaque",
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

uint64_t mlir_make_attr_dense_resource(uint64_t /*ctx_ptr*/, ptr value) {
  auto result_type_ptr = Sunsigned64_value(Scar(value));
  std::string key_str = schemeStringToStd(Scar(Scdr(value)));
  int64_t data_addr = Sinteger64_value(Scar(Scdr(Scdr(value))));
  int64_t data_size = Sinteger64_value(Scar(Scdr(Scdr(Scdr(value)))));

  auto baseType = mlir::Type::getFromOpaquePointer(
      reinterpret_cast<const void*>(result_type_ptr));
  auto resultType = llvm::dyn_cast<mlir::RankedTensorType>(baseType);
  if (!resultType) {
    scheme_error("mlir-make-attr :dense-resource",
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
// Op-level attribute get/set
//===----------------------------------------------------------------------===//

uint64_t mlir_operation_get_attribute(uint64_t op_ptr, const char* name) {
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto attr = op->getAttr(name);
  if (!attr) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(attr.getAsOpaquePointer());
}

void mlir_operation_set_attribute(uint64_t op_ptr, const char* name,
                                  uint64_t attr_ptr) {
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  op->setAttr(name, attr);
}

//===----------------------------------------------------------------------===//
// Type inspection
//===----------------------------------------------------------------------===//

uint64_t mlir_type_element_type(uint64_t type_ptr) {
  if (!type_ptr) {
    return 0;
  }
  auto type =
      mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(type_ptr));
  if (auto st = mlir::dyn_cast<mlir::ShapedType>(type)) {
    return reinterpret_cast<uint64_t>(st.getElementType().getAsOpaquePointer());
  }
  return 0;
}

uint64_t mlir_type_integer_width(uint64_t type_ptr) {
  if (!type_ptr) {
    return 0;
  }
  auto type =
      mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(type_ptr));
  if (auto it = mlir::dyn_cast<mlir::IntegerType>(type)) {
    return static_cast<uint64_t>(it.getWidth());
  }
  return 0;
}

int mlir_type_is_unsigned(uint64_t type_ptr) {
  if (!type_ptr) {
    return 0;
  }
  auto type =
      mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(type_ptr));
  if (auto it = mlir::dyn_cast<mlir::IntegerType>(type)) {
    return it.isUnsigned() ? 1 : 0;
  }
  return 0;
}

//===----------------------------------------------------------------------===//
// Attribute inspection — legacy helpers (not open-ended)
//===----------------------------------------------------------------------===//

double mlir_op_get_float_attr(uint64_t op_ptr, const char* name) {
  if (!op_ptr || !name) {
    return std::numeric_limits<double>::quiet_NaN();
  }
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto attr = op->getAttrOfType<mlir::FloatAttr>(name);
  if (!attr) {
    return std::numeric_limits<double>::quiet_NaN();
  }
  return attr.getValueAsDouble();
}

int mlir_attr_is_splat(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  auto dense = mlir::dyn_cast<mlir::DenseElementsAttr>(attr);
  return (dense && dense.isSplat()) ? 1 : 0;
}

double mlir_attr_splat_float_value(uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error("mlir-attr-splat-float-value", "null attribute pointer");
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  auto dense = mlir::dyn_cast<mlir::DenseFPElementsAttr>(attr);
  if (!dense) {
    scheme_error("mlir-attr-splat-float-value",
                 "attribute is not a DenseFPElementsAttr");
  }
  if (!dense.isSplat()) {
    scheme_error("mlir-attr-splat-float-value",
                 "DenseFPElementsAttr is not a splat");
  }
  return (*dense.begin()).convertToDouble();
}

int64_t mlir_attr_splat_int_value(uint64_t attr_ptr, int64_t absent_val) {
  if (!attr_ptr) {
    return absent_val;
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  auto dense = mlir::dyn_cast<mlir::DenseIntElementsAttr>(attr);
  if (!dense || !dense.isSplat()) {
    return absent_val;
  }
  return (*dense.begin()).getSExtValue();
}

//===----------------------------------------------------------------------===//
// mlir_attr_isa_* family: (uint64_t attr) → int
//===----------------------------------------------------------------------===//

int mlir_attr_isa_integer(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  return mlir::isa<mlir::IntegerAttr>(attr) ? 1 : 0;
}

int mlir_attr_isa_float(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  return mlir::isa<mlir::FloatAttr>(attr) ? 1 : 0;
}

int mlir_attr_isa_string(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  return mlir::isa<mlir::StringAttr>(attr) ? 1 : 0;
}

int mlir_attr_isa_array_ref_i32(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  return mlir::isa<mlir::DenseI32ArrayAttr>(attr) ? 1 : 0;
}

int mlir_attr_isa_dense_elements(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  return mlir::isa<mlir::DenseElementsAttr>(attr) ? 1 : 0;
}

//===----------------------------------------------------------------------===//
// mlir_attr_isa_dense_elements_splat — compound predicate: DenseElementsAttr &&
// isSplat
//===----------------------------------------------------------------------===//

int mlir_attr_isa_dense_elements_splat(uint64_t attr_ptr) {
  if (!attr_ptr) {
    return 0;
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  auto dense = mlir::dyn_cast<mlir::DenseElementsAttr>(attr);
  return (dense && dense.isSplat()) ? 1 : 0;
}

//===----------------------------------------------------------------------===//
// mlir_attr_into_* family: (uint64_t attr) → ptr (boxed Scheme value)
// General conversion for complex types — may allocate Scheme objects.
//===----------------------------------------------------------------------===//

// Splat float value from DenseFPElementsAttr → Scheme flonum.
ptr mlir_attr_into_splat_float(uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error("mlir-attr-into :splat-float", "null attribute pointer");
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  auto dense = mlir::dyn_cast<mlir::DenseFPElementsAttr>(attr);
  if (!dense) {
    scheme_error("mlir-attr-into :splat-float",
                 "attribute is not a DenseFPElementsAttr");
  }
  if (!dense.isSplat()) {
    scheme_error("mlir-attr-into :splat-float",
                 "DenseFPElementsAttr is not a splat");
  }
  return Sflonum((*dense.begin()).convertToDouble());
}

// Splat integer value from DenseIntElementsAttr → Scheme integer.
ptr mlir_attr_into_splat_integer(uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error("mlir-attr-into :splat-integer", "null attribute pointer");
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  auto dense = mlir::dyn_cast<mlir::DenseIntElementsAttr>(attr);
  if (!dense) {
    scheme_error("mlir-attr-into :splat-integer",
                 "attribute is not a DenseIntElementsAttr");
  }
  if (!dense.isSplat()) {
    scheme_error("mlir-attr-into :splat-integer",
                 "DenseIntElementsAttr is not a splat");
  }
  return Sinteger64((*dense.begin()).getSExtValue());
}

// DenseI32ArrayAttr → Scheme list of fixnums.
ptr mlir_attr_into_i32_array(uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error("mlir-attr-into :i32-array", "null attribute pointer");
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  auto arr = mlir::dyn_cast<mlir::DenseI32ArrayAttr>(attr);
  if (!arr) {
    scheme_error("mlir-attr-into :i32-array",
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
// mlir_attr_as_* family: (uint64_t attr) → ptr (boxed Scheme value)
// Fast scalar extraction. Callers should verify type with mlir_attr_isa_*
// first; signals Scheme error on type mismatch.
//===----------------------------------------------------------------------===//

ptr mlir_attr_as_integer(uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error("mlir-attr-as :integer", "null attribute pointer");
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  auto iattr = mlir::dyn_cast<mlir::IntegerAttr>(attr);
  if (!iattr) {
    scheme_error("mlir-attr-as :integer", "attribute is not an IntegerAttr");
  }
  return Sinteger64(iattr.getValue().getSExtValue());
}

ptr mlir_attr_as_float(uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error("mlir-attr-as :float", "null attribute pointer");
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  auto fattr = mlir::dyn_cast<mlir::FloatAttr>(attr);
  if (!fattr) {
    scheme_error("mlir-attr-as :float", "attribute is not a FloatAttr");
  }
  return Sflonum(fattr.getValueAsDouble());
}

// mlir_attr_isa_f32 / mlir_attr_as_f32 — registered under the 'f32 type key.
// Allows (mlir-attr-isa attr :f32) and (mlir-attr-as attr :f32).
int mlir_attr_isa_f32(uint64_t attr_ptr) {
  return mlir_attr_isa_float(attr_ptr);
}
ptr mlir_attr_as_f32(uint64_t attr_ptr) { return mlir_attr_as_float(attr_ptr); }

//===----------------------------------------------------------------------===//
// mlir_attr_as_array_ref_i32 — zero-copy access to DenseI32ArrayAttr data
//
// Returns a uptr to a heap-allocated CArrayRef{data, size} that points
// directly into the attr's internal int32_t buffer (no data copy).
//
// Lifetime of the returned uptr (the CArrayRef header):
//   Valid until mlir_array_ref_destroy is called on it. After that it is a
//   dangling pointer regardless of MLIRContext state.
//   Use (with-array-ref ...) or (array-ref-destroy ref) to ensure cleanup.
//
// Lifetime of the data it points to (the attr's internal buffer):
//   Valid as long as the MLIRContext is alive (attrs are context-owned,
//   uniqued, and never relocated).
//===----------------------------------------------------------------------===//

uint64_t mlir_attr_as_array_ref_i32(uint64_t attr_ptr) {
  if (!attr_ptr) {
    scheme_error("mlir-attr-as-array-ref-i32", "null attribute pointer");
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  auto arr = mlir::dyn_cast<mlir::DenseI32ArrayAttr>(attr);
  if (!arr) {
    scheme_error("mlir-attr-as-array-ref-i32",
                 "attribute is not a DenseI32ArrayAttr");
  }
  // Point directly into the attr's internal storage — zero data copy.
  auto* ref = new CArrayRef{reinterpret_cast<uint64_t>(arr.asArrayRef().data()),
                            static_cast<uint64_t>(arr.size())};
  return reinterpret_cast<uint64_t>(ref);
}

} // extern "C"

namespace crest {

void registerAttributeBindings() {
  // mlir_make_attr_* — registered explicitly so foreign-entry? finds them.
  Sregister_symbol("mlir_make_attr_i64", (void*)::mlir_make_attr_i64);
  Sregister_symbol("mlir_make_attr_f32", (void*)::mlir_make_attr_f32);
  Sregister_symbol("mlir_make_attr_index", (void*)::mlir_make_attr_index);
  Sregister_symbol("mlir_make_attr_i32_array",
                   (void*)::mlir_make_attr_i32_array);
  Sregister_symbol("mlir_make_attr_i64_array",
                   (void*)::mlir_make_attr_i64_array);
  Sregister_symbol("mlir_make_attr_opaque", (void*)::mlir_make_attr_opaque);
  Sregister_symbol("mlir_make_attr_dense_resource",
                   (void*)::mlir_make_attr_dense_resource);
  // Op-level get/set.
  Sregister_symbol("mlir_operation_get_attribute",
                   (void*)::mlir_operation_get_attribute);
  Sregister_symbol("mlir_operation_set_attribute",
                   (void*)::mlir_operation_set_attribute);
  // Type inspection.
  Sregister_symbol("mlir_type_element_type", (void*)::mlir_type_element_type);
  Sregister_symbol("mlir_type_integer_width", (void*)::mlir_type_integer_width);
  Sregister_symbol("mlir_type_is_unsigned", (void*)::mlir_type_is_unsigned);
  // Legacy attribute inspection helpers.
  Sregister_symbol("mlir_op_get_float_attr", (void*)::mlir_op_get_float_attr);
  Sregister_symbol("mlir_attr_is_splat", (void*)::mlir_attr_is_splat);
  Sregister_symbol("mlir_attr_splat_float_value",
                   (void*)::mlir_attr_splat_float_value);
  Sregister_symbol("mlir_attr_splat_int_value",
                   (void*)::mlir_attr_splat_int_value);
  // All mlir_attr_isa_*, mlir_attr_as_*, mlir_attr_into_* must be registered
  // so that foreign-entry? returns true and the open-ended lookup finds them.
  Sregister_symbol("mlir_attr_isa_integer", (void*)::mlir_attr_isa_integer);
  Sregister_symbol("mlir_attr_isa_float", (void*)::mlir_attr_isa_float);
  Sregister_symbol("mlir_attr_isa_string", (void*)::mlir_attr_isa_string);
  Sregister_symbol("mlir_attr_isa_array_ref_i32",
                   (void*)::mlir_attr_isa_array_ref_i32);
  Sregister_symbol("mlir_attr_isa_dense_elements",
                   (void*)::mlir_attr_isa_dense_elements);
  Sregister_symbol("mlir_attr_isa_dense_elements_splat",
                   (void*)::mlir_attr_isa_dense_elements_splat);
  Sregister_symbol("mlir_attr_as_integer", (void*)::mlir_attr_as_integer);
  Sregister_symbol("mlir_attr_as_float", (void*)::mlir_attr_as_float);
  Sregister_symbol("mlir_attr_as_array_ref_i32",
                   (void*)::mlir_attr_as_array_ref_i32);
  Sregister_symbol("mlir_attr_isa_f32", (void*)::mlir_attr_isa_f32);
  Sregister_symbol("mlir_attr_as_f32", (void*)::mlir_attr_as_f32);
  Sregister_symbol("mlir_attr_into_splat_float",
                   (void*)::mlir_attr_into_splat_float);
  Sregister_symbol("mlir_attr_into_splat_integer",
                   (void*)::mlir_attr_into_splat_integer);
  Sregister_symbol("mlir_attr_into_i32_array",
                   (void*)::mlir_attr_into_i32_array);
}

} // namespace crest

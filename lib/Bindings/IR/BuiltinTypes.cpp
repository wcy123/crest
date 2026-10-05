/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/BuiltinTypes.h — builtin type constructors and queries.

#include "BuiltinTypes.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Types.h"

static void scheme_error(const char* who, const char* msg) {
  Scall2(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring(msg));
}

extern "C" {

// mlir::IndexType::get(ctx)
uint64_t mlir_ir_builtin_types_index_type_get(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir-ir-builtin-types-index-type-get",
                 "null MLIRContext pointer");
  }
  return reinterpret_cast<uint64_t>(
      mlir::IndexType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
          .getAsOpaquePointer());
}

// mlir::IntegerType::get(ctx, 64)
uint64_t mlir_ir_builtin_types_integer_type_get_i64(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir-ir-builtin-types-integer-type-get-i64",
                 "null MLIRContext pointer");
  }
  return reinterpret_cast<uint64_t>(
      mlir::IntegerType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr), 64)
          .getAsOpaquePointer());
}

// mlir::IntegerType::get(ctx, 1)
uint64_t mlir_ir_builtin_types_integer_type_get_i1(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir-ir-builtin-types-integer-type-get-i1",
                 "null MLIRContext pointer");
  }
  return reinterpret_cast<uint64_t>(
      mlir::IntegerType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr), 1)
          .getAsOpaquePointer());
}

// mlir::isa<mlir::RankedTensorType>(type)
int mlir_ir_builtin_types_ranked_tensor_type_isa(uint64_t type_ptr) {
  if (!type_ptr) {
    return 0;
  }
  return mlir::isa<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
             reinterpret_cast<const void*>(type_ptr)))
             ? 1
             : 0;
}

// mlir::RankedTensorType::getRank()
int64_t mlir_ir_builtin_types_ranked_tensor_type_get_rank(uint64_t type_ptr) {
  if (!type_ptr) {
    scheme_error("mlir-ir-builtin-types-ranked-tensor-type-get-rank",
                 "null type pointer");
  }
  auto t =
      mlir::dyn_cast<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
          reinterpret_cast<const void*>(type_ptr)));
  if (!t) {
    scheme_error("mlir-ir-builtin-types-ranked-tensor-type-get-rank",
                 "type is not a RankedTensorType");
  }
  return t.getRank();
}

// mlir::RankedTensorType::getElementType()
uint64_t
mlir_ir_builtin_types_ranked_tensor_type_get_element_type(uint64_t type_ptr) {
  if (!type_ptr) {
    scheme_error("mlir-ir-builtin-types-ranked-tensor-type-get-element-type",
                 "null type pointer");
  }
  auto t =
      mlir::dyn_cast<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
          reinterpret_cast<const void*>(type_ptr)));
  if (!t) {
    scheme_error("mlir-ir-builtin-types-ranked-tensor-type-get-element-type",
                 "type is not a RankedTensorType");
  }
  return reinterpret_cast<uint64_t>(
      const_cast<void*>(t.getElementType().getAsOpaquePointer()));
}

// mlir::RankedTensorType::getShape() → Scheme list of integers
ptr mlir_ir_builtin_types_ranked_tensor_type_get_shape(ptr type_ptr) {
  if (!type_ptr) {
    scheme_error("mlir-ir-builtin-types-ranked-tensor-type-get-shape",
                 "null type pointer");
  }
  auto t = llvm::dyn_cast<mlir::RankedTensorType>(
      mlir::Type::getFromOpaquePointer(type_ptr));
  if (!t) {
    scheme_error("mlir-ir-builtin-types-ranked-tensor-type-get-shape",
                 "type is not a RankedTensorType");
  }
  ptr list = Snil;
  for (int i = static_cast<int>(t.getShape().size()) - 1; i >= 0; --i) {
    list = Scons(Sinteger(t.getShape()[i]), list);
  }
  return list;
}

// mlir::RankedTensorType::getEncoding()
uint64_t
mlir_ir_builtin_types_ranked_tensor_type_get_encoding(uint64_t type_ptr) {
  if (!type_ptr) {
    scheme_error("mlir-ir-builtin-types-ranked-tensor-type-get-encoding",
                 "null type pointer");
  }
  auto t =
      mlir::dyn_cast<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
          reinterpret_cast<const void*>(type_ptr)));
  if (!t) {
    scheme_error("mlir-ir-builtin-types-ranked-tensor-type-get-encoding",
                 "type is not a RankedTensorType");
  }
  mlir::Attribute enc = t.getEncoding();
  return enc ? reinterpret_cast<uint64_t>(enc.getAsOpaquePointer()) : 0;
}

// mlir::RankedTensorType::cloneWithEncoding(attr)
uint64_t mlir_ir_builtin_types_ranked_tensor_type_clone_with_encoding(
    uint64_t type_ptr, uint64_t attr_ptr) {
  if (!type_ptr) {
    scheme_error("mlir-ir-builtin-types-ranked-tensor-type-clone-with-encoding",
                 "null type pointer");
  }
  if (!attr_ptr) {
    scheme_error("mlir-ir-builtin-types-ranked-tensor-type-clone-with-encoding",
                 "null attribute pointer");
  }
  auto t =
      mlir::dyn_cast<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
          reinterpret_cast<const void*>(type_ptr)));
  if (!t) {
    scheme_error("mlir-ir-builtin-types-ranked-tensor-type-clone-with-encoding",
                 "type is not a RankedTensorType");
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  return reinterpret_cast<uint64_t>(
      t.cloneWithEncoding(attr).getAsOpaquePointer());
}

// mlir::ShapedType::getElementType()
uint64_t mlir_ir_builtin_types_shaped_type_get_element_type(uint64_t type_ptr) {
  if (!type_ptr) {
    scheme_error("mlir-ir-builtin-types-shaped-type-get-element-type",
                 "null type pointer");
  }
  auto type =
      mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(type_ptr));
  auto st = mlir::dyn_cast<mlir::ShapedType>(type);
  if (!st) {
    scheme_error("mlir-ir-builtin-types-shaped-type-get-element-type",
                 "type is not a ShapedType");
  }
  return reinterpret_cast<uint64_t>(st.getElementType().getAsOpaquePointer());
}

// mlir::IntegerType::getWidth()
uint64_t mlir_ir_builtin_types_integer_type_get_width(uint64_t type_ptr) {
  if (!type_ptr) {
    scheme_error("mlir-ir-builtin-types-integer-type-get-width",
                 "null type pointer");
  }
  auto type =
      mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(type_ptr));
  auto it = mlir::dyn_cast<mlir::IntegerType>(type);
  if (!it) {
    scheme_error("mlir-ir-builtin-types-integer-type-get-width",
                 "type is not an IntegerType");
  }
  return static_cast<uint64_t>(it.getWidth());
}

// mlir::IntegerType::isUnsigned()
int mlir_ir_builtin_types_integer_type_is_unsigned(uint64_t type_ptr) {
  if (!type_ptr) {
    scheme_error("mlir-ir-builtin-types-integer-type-is-unsigned",
                 "null type pointer");
  }
  auto type =
      mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(type_ptr));
  auto it = mlir::dyn_cast<mlir::IntegerType>(type);
  if (!it) {
    scheme_error("mlir-ir-builtin-types-integer-type-is-unsigned",
                 "type is not an IntegerType");
  }
  return it.isUnsigned() ? 1 : 0;
}

} // extern "C"

namespace crest {

void registerIRBuiltinTypesBindings() {
  Sregister_symbol("mlir_ir_builtin_types_index_type_get",
                   (void*)::mlir_ir_builtin_types_index_type_get);
  Sregister_symbol("mlir_ir_builtin_types_integer_type_get_i64",
                   (void*)::mlir_ir_builtin_types_integer_type_get_i64);
  Sregister_symbol("mlir_ir_builtin_types_integer_type_get_i1",
                   (void*)::mlir_ir_builtin_types_integer_type_get_i1);
  Sregister_symbol("mlir_ir_builtin_types_ranked_tensor_type_isa",
                   (void*)::mlir_ir_builtin_types_ranked_tensor_type_isa);
  Sregister_symbol("mlir_ir_builtin_types_ranked_tensor_type_get_rank",
                   (void*)::mlir_ir_builtin_types_ranked_tensor_type_get_rank);
  Sregister_symbol(
      "mlir_ir_builtin_types_ranked_tensor_type_get_element_type",
      (void*)::mlir_ir_builtin_types_ranked_tensor_type_get_element_type);
  Sregister_symbol("mlir_ir_builtin_types_ranked_tensor_type_get_shape",
                   (void*)::mlir_ir_builtin_types_ranked_tensor_type_get_shape);
  Sregister_symbol(
      "mlir_ir_builtin_types_ranked_tensor_type_get_encoding",
      (void*)::mlir_ir_builtin_types_ranked_tensor_type_get_encoding);
  Sregister_symbol(
      "mlir_ir_builtin_types_ranked_tensor_type_clone_with_encoding",
      (void*)::mlir_ir_builtin_types_ranked_tensor_type_clone_with_encoding);
  // ── Type query functions (moved from BuiltinAttributes.cpp) ─────────────
  Sregister_symbol("mlir_ir_builtin_types_shaped_type_get_element_type",
                   (void*)::mlir_ir_builtin_types_shaped_type_get_element_type);
  Sregister_symbol("mlir_ir_builtin_types_integer_type_get_width",
                   (void*)::mlir_ir_builtin_types_integer_type_get_width);
  Sregister_symbol("mlir_ir_builtin_types_integer_type_is_unsigned",
                   (void*)::mlir_ir_builtin_types_integer_type_is_unsigned);
  // ── Old names (backward compat) ──────────────────────────────────────────
  Sregister_symbol("mlir_ir_builtin_attributes_shaped_type_get_element_type",
                   (void*)::mlir_ir_builtin_types_shaped_type_get_element_type);
  Sregister_symbol("mlir_ir_builtin_attributes_integer_type_get_width",
                   (void*)::mlir_ir_builtin_types_integer_type_get_width);
  Sregister_symbol("mlir_ir_builtin_attributes_integer_type_is_unsigned",
                   (void*)::mlir_ir_builtin_types_integer_type_is_unsigned);
  Sregister_symbol("mlir_type_element_type",
                   (void*)::mlir_ir_builtin_types_shaped_type_get_element_type);
  Sregister_symbol("mlir_type_integer_width",
                   (void*)::mlir_ir_builtin_types_integer_type_get_width);
  Sregister_symbol("mlir_type_is_unsigned",
                   (void*)::mlir_ir_builtin_types_integer_type_is_unsigned);
}

} // namespace crest

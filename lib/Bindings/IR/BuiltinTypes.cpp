/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/BuiltinTypes.h — builtin type constructors and queries.

#include "BuiltinTypes.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Types.h"

extern "C" {

// mlir::IndexType::get(ctx)
uint64_t mlir_ir_builtin_types_index_type_get(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      mlir::IndexType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
          .getAsOpaquePointer());
}

// mlir::IntegerType::get(ctx, 64)
uint64_t mlir_ir_builtin_types_integer_type_get_i64(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      mlir::IntegerType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr), 64)
          .getAsOpaquePointer());
}

// mlir::IntegerType::get(ctx, 1)
uint64_t mlir_ir_builtin_types_integer_type_get_i1(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    return 0;
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
    return -1;
  }
  auto t =
      mlir::dyn_cast<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
          reinterpret_cast<const void*>(type_ptr)));
  return t ? t.getRank() : -1;
}

// mlir::RankedTensorType::getElementType()
uint64_t
mlir_ir_builtin_types_ranked_tensor_type_get_element_type(uint64_t type_ptr) {
  if (!type_ptr) {
    return 0;
  }
  auto t =
      mlir::dyn_cast<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
          reinterpret_cast<const void*>(type_ptr)));
  if (!t) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      const_cast<void*>(t.getElementType().getAsOpaquePointer()));
}

// mlir::RankedTensorType::getShape() → Scheme list of integers
ptr mlir_ir_builtin_types_ranked_tensor_type_get_shape(ptr type_ptr) {
  if (!type_ptr) {
    return Snil;
  }
  auto t = llvm::dyn_cast<mlir::RankedTensorType>(
      mlir::Type::getFromOpaquePointer(type_ptr));
  if (!t) {
    return Snil;
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
    return 0;
  }
  auto t =
      mlir::dyn_cast<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
          reinterpret_cast<const void*>(type_ptr)));
  if (!t) {
    return 0;
  }
  mlir::Attribute enc = t.getEncoding();
  return enc ? reinterpret_cast<uint64_t>(enc.getAsOpaquePointer()) : 0;
}

// mlir::RankedTensorType::cloneWithEncoding(attr)
uint64_t mlir_ir_builtin_types_ranked_tensor_type_clone_with_encoding(
    uint64_t type_ptr, uint64_t attr_ptr) {
  if (!type_ptr || !attr_ptr) {
    return 0;
  }
  auto t =
      mlir::dyn_cast<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
          reinterpret_cast<const void*>(type_ptr)));
  if (!t) {
    return 0;
  }
  auto attr = mlir::Attribute::getFromOpaquePointer(
      reinterpret_cast<const void*>(attr_ptr));
  return reinterpret_cast<uint64_t>(
      t.cloneWithEncoding(attr).getAsOpaquePointer());
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
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors (mlir core types): type constructors and type queries.
// All functions operate on opaque type/value pointers and return opaque
// pointers — no MLIR C++ types cross the FFI boundary.

#include "mlir/IR/Types.h"
#include "../SchemeWrapper.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Value.h"

extern "C" {

// ─── Context extraction
// ───────────────────────────────────────────────────────

// Get the MLIRContext* that owns this type.
// type_ptr: Type opaque uptr (Type::getAsOpaquePointer())
// Returns:  MLIRContext* uptr, or 0 on null input.
uint64_t mlir_type_get_context(uint64_t type_ptr) {
  if (!type_ptr) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(type_ptr))
          .getContext());
}

// ─── Type constructors
// ────────────────────────────────────────────────────────

// Return the built-in IndexType for a context.
// ctx_ptr: MLIRContext* uptr
// Returns: IndexType opaque uptr, or 0 if ctx is null.
uint64_t mlir_get_index_type(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      mlir::IndexType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
          .getAsOpaquePointer());
}

// Return IntegerType<64> (signless) for a context.
// ctx_ptr: MLIRContext* uptr
// Returns: IntegerType<64> opaque uptr, or 0 if ctx is null.
uint64_t mlir_get_i64_type(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      mlir::IntegerType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr), 64)
          .getAsOpaquePointer());
}

// Return IntegerType<1> (i1 / boolean) for a context.
// ctx_ptr: MLIRContext* uptr
// Returns: IntegerType<1> opaque uptr, or 0 if ctx is null.
uint64_t mlir_get_i1_type(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      mlir::IntegerType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr), 1)
          .getAsOpaquePointer());
}

// ─── Type queries
// ─────────────────────────────────────────────────────────────

// Return 1 if the type is a RankedTensorType, 0 otherwise.
// type_ptr: Type opaque uptr
// Returns:  int (1 = true, 0 = false)
int mlir_type_is_ranked_tensor(uint64_t type_ptr) {
  if (!type_ptr) {
    return 0;
  }
  return mlir::isa<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
             reinterpret_cast<void*>(type_ptr)))
             ? 1
             : 0;
}

// Get the rank (number of dimensions) of a RankedTensorType.
// type_ptr: RankedTensorType opaque uptr
// Returns:  non-negative int64_t, or -1 if not a RankedTensorType.
int64_t mlir_type_get_rank(uint64_t type_ptr) {
  if (!type_ptr) {
    return -1;
  }
  auto t = mlir::dyn_cast<mlir::RankedTensorType>(
      mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr)));
  return t ? t.getRank() : -1;
}

// Get the element type of a ShapedType (tensor, memref, vector).
// type_ptr: ShapedType opaque uptr
// Returns:  element Type opaque uptr, or 0 if not a ShapedType.
uint64_t mlir_type_get_element_type(uint64_t type_ptr) {
  if (!type_ptr) {
    return 0;
  }
  auto t = mlir::dyn_cast<mlir::RankedTensorType>(
      mlir::Type::getFromOpaquePointer(reinterpret_cast<void*>(type_ptr)));
  if (!t) {
    return 0;
  }
  return reinterpret_cast<uint64_t>(
      const_cast<void*>(t.getElementType().getAsOpaquePointer()));
}

// Get the shape of a RankedTensorType as a Scheme list of exact integers.
// Negative values represent dynamic dimensions (mlir::ShapedType::kDynamic).
// type_ptr: RankedTensorType opaque ptr (raw Chez Scheme ptr, not uptr)
// Returns:  Scheme list of exact integers, or Snil if not a RankedTensorType.
ptr mlir_type_get_shape(ptr type_ptr) {
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

// Get the encoding attribute of a RankedTensorType (e.g. for memory space).
// type_ptr: RankedTensorType opaque uptr
// Returns:  Attribute opaque uptr, or 0 if the type has no encoding.
uint64_t mlir_type_get_encoding(uint64_t type_ptr) {
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

// Clone a RankedTensorType with a new encoding attribute.
// type_ptr: RankedTensorType opaque uptr
// attr_ptr: Attribute opaque uptr — the encoding to attach
// Returns:  new RankedTensorType opaque uptr, or 0 on bad input.
uint64_t mlir_tensor_type_with_encoding(uint64_t type_ptr, uint64_t attr_ptr) {
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

// ─── Value type
// ───────────────────────────────────────────────────────────────

// Get the MLIR type of a Value.
// value_ptr: Value opaque ptr (raw Chez Scheme ptr)
// Returns:   Type opaque ptr, or null if value_ptr is null.
ptr mlir_value_get_type(ptr value_ptr) {
  if (!value_ptr) {
    return nullptr;
  }
  return const_cast<void*>(mlir::Value::getFromOpaquePointer(value_ptr)
                               .getType()
                               .getAsOpaquePointer());
}

} // extern "C"

namespace crest {

void registerTypeBindings() {
  Sregister_symbol("mlir_type_get_context", (void*)::mlir_type_get_context);
  Sregister_symbol("mlir_get_index_type", (void*)::mlir_get_index_type);
  Sregister_symbol("mlir_get_i64_type", (void*)::mlir_get_i64_type);
  Sregister_symbol("mlir_get_i1_type", (void*)::mlir_get_i1_type);
  Sregister_symbol("mlir_type_is_ranked_tensor",
                   (void*)::mlir_type_is_ranked_tensor);
  Sregister_symbol("mlir_type_get_rank", (void*)::mlir_type_get_rank);
  Sregister_symbol("mlir_type_get_element_type",
                   (void*)::mlir_type_get_element_type);
  Sregister_symbol("mlir_type_get_shape", (void*)::mlir_type_get_shape);
  Sregister_symbol("mlir_type_get_encoding", (void*)::mlir_type_get_encoding);
  Sregister_symbol("mlir_tensor_type_with_encoding",
                   (void*)::mlir_tensor_type_with_encoding);
  Sregister_symbol("mlir_value_get_type", (void*)::mlir_value_get_type);
}

} // namespace crest

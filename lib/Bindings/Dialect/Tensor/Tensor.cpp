/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/Tensor/IR/Tensor.h — tensor op bindings.

#include "Tensor.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Dialect/Tensor/IR/Tensor.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/Value.h"

extern "C" {

// mlir::tensor::CastOp::areCastCompatible(fromType, toType) — returns 1 if a
// tensor.cast between the two types is valid, 0 otherwise.
// Both type_ptr arguments are opaque type pointers.
static int mlir_dialect_tensor_cast_are_cast_compatible(uint64_t from_type_ptr,
                                                        uint64_t to_type_ptr) {
  if (!from_type_ptr || !to_type_ptr) {
    return 0;
  }
  auto fromType = mlir::Type::getFromOpaquePointer(
      reinterpret_cast<const void*>(from_type_ptr));
  auto toType = mlir::Type::getFromOpaquePointer(
      reinterpret_cast<const void*>(to_type_ptr));
  return mlir::tensor::CastOp::areCastCompatible(fromType, toType) ? 1 : 0;
}

// mlir::tensor::CastOp::create(builder, loc, resultType, input) — insert a
// tensor.cast op and return its result value as a uptr.
// builder_ptr: OpBuilder* uptr
// loc_ptr:     Location opaque uptr (from mlir::Location::getAsOpaquePointer)
// result_type_ptr: Type opaque uptr
// input_value_ptr: Value opaque uptr
// Returns: Value opaque uptr of the cast result, or 0 on failure.
static uint64_t mlir_dialect_tensor_cast_create(uint64_t builder_ptr,
                                                uint64_t loc_ptr,
                                                uint64_t result_type_ptr,
                                                uint64_t input_value_ptr) {
  if (!builder_ptr || !loc_ptr || !result_type_ptr || !input_value_ptr) {
    return 0;
  }
  auto* builder = reinterpret_cast<mlir::OpBuilder*>(builder_ptr);
  auto loc = mlir::Location::getFromOpaquePointer(
      reinterpret_cast<const void*>(loc_ptr));
  auto resultType = mlir::Type::getFromOpaquePointer(
      reinterpret_cast<const void*>(result_type_ptr));
  auto input = mlir::Value::getFromOpaquePointer(
      reinterpret_cast<const void*>(input_value_ptr));
  auto castOp = mlir::tensor::CastOp::create(*builder, loc, resultType, input);
  return reinterpret_cast<uint64_t>(castOp.getResult().getAsOpaquePointer());
}

} // extern "C"

namespace crest {

void registerDialectTensorBindings() {
  Sregister_symbol("mlir::tensor::CastOp::areCastCompatible",
                   (void*)::mlir_dialect_tensor_cast_are_cast_compatible);
  Sregister_symbol("mlir::tensor::CastOp::create",
                   (void*)::mlir_dialect_tensor_cast_create);
}

} // namespace crest

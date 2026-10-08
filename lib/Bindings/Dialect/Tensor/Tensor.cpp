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

namespace crest {

void registerDialectTensorBindings() {
  Sregister_symbol(
      "mlir::tensor::CastOp::areCastCompatible",
      (void*)+[](uint64_t from_type_ptr, uint64_t to_type_ptr) -> int {
        if (!from_type_ptr || !to_type_ptr) {
          return 0;
        }
        auto fromType = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(from_type_ptr));
        auto toType = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(to_type_ptr));
        return mlir::tensor::CastOp::areCastCompatible(fromType, toType) ? 1
                                                                         : 0;
      });
  Sregister_symbol(
      "mlir::tensor::CastOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr,
                 uint64_t result_type_ptr,
                 uint64_t input_value_ptr) -> uint64_t {
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
        auto castOp =
            mlir::tensor::CastOp::create(*builder, loc, resultType, input);
        return reinterpret_cast<uint64_t>(
            castOp.getResult().getAsOpaquePointer());
      });
}

} // namespace crest

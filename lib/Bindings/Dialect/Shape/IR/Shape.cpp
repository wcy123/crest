/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/Shape/IR/Shape.h — type factory bindings.

#include "../Shape.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/Shape/IR/Shape.h"
#include "mlir/IR/MLIRContext.h"

namespace crest {

void registerDialectShapeBindings() {
  Sregister_symbol(
      "mlir::shape::ShapeType::get", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::shape::ShapeType::get", "ctx must not be null");
        }
        return reinterpret_cast<uint64_t>(
            mlir::shape::ShapeType::get(
                reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::shape::SizeType::get", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::shape::SizeType::get", "ctx must not be null");
        }
        return reinterpret_cast<uint64_t>(
            mlir::shape::SizeType::get(
                reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::shape::WitnessType::get",
      (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::shape::WitnessType::get", "ctx must not be null");
        }
        return reinterpret_cast<uint64_t>(
            mlir::shape::WitnessType::get(
                reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
                .getAsOpaquePointer());
      });
}

} // namespace crest

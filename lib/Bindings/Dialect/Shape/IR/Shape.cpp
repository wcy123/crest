/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/Shape/IR/Shape.h — type factory bindings.

#include "Shape.h"
#include "../../../Support/Result.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/Shape/IR/Shape.h"
#include "mlir/IR/MLIRContext.h"

namespace crest {

void registerDialectShapeBindings() {
  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext* → mlir::shape::ShapeType
  /// (opaque)
  Sregister_symbol(
      "mlir::shape::ShapeType::get", (void*)+[](uint64_t ctx_ptr) -> ptr {
        if (!ctx_ptr) {
          return scheme_error("mlir::shape::ShapeType::get",
                              "ctx must not be null");
        }
        auto* crest_lookup1 = crest::as_context(ctx_ptr);

        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::shape::ShapeType::get(crest_lookup1).getAsOpaquePointer()));
      });
  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext* → mlir::shape::SizeType
  /// (opaque)
  Sregister_symbol(
      "mlir::shape::SizeType::get", (void*)+[](uint64_t ctx_ptr) -> ptr {
        if (!ctx_ptr) {
          return scheme_error("mlir::shape::SizeType::get",
                              "ctx must not be null");
        }
        auto* crest_lookup1 = crest::as_context(ctx_ptr);

        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::shape::SizeType::get(crest_lookup1).getAsOpaquePointer()));
      });
  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext* →
  /// mlir::shape::WitnessType (opaque)
  Sregister_symbol(
      "mlir::shape::WitnessType::get", (void*)+[](uint64_t ctx_ptr) -> ptr {
        if (!ctx_ptr) {
          return scheme_error("mlir::shape::WitnessType::get",
                              "ctx must not be null");
        }
        auto* crest_lookup1 = crest::as_context(ctx_ptr);

        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::shape::WitnessType::get(crest_lookup1).getAsOpaquePointer()));
      });
}

} // namespace crest

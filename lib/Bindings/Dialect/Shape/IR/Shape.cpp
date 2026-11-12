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
  register_binding(
      "mlir::shape::ShapeType::get",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::shape::ShapeType::get",
                      llvm::Twine("ctx must not be null"));
        }
        CREST_TRY(crest_lookup1,
                  crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::shape::ShapeType::get(crest_lookup1).getAsOpaquePointer());
      });
  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext* → mlir::shape::SizeType
  /// (opaque)
  register_binding(
      "mlir::shape::SizeType::get",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::shape::SizeType::get",
                      llvm::Twine("ctx must not be null"));
        }
        CREST_TRY(crest_lookup1,
                  crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::shape::SizeType::get(crest_lookup1).getAsOpaquePointer());
      });
  /// ctx_ptr: CrestBox<MLIRContext>* | MLIRContext* →
  /// mlir::shape::WitnessType (opaque)
  register_binding(
      "mlir::shape::WitnessType::get",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::shape::WitnessType::get",
                      llvm::Twine("ctx must not be null"));
        }
        CREST_TRY(crest_lookup1,
                  crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::shape::WitnessType::get(crest_lookup1).getAsOpaquePointer());
      });
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/Shape/IR/Shape.h — type factory bindings.

#include "../Shape.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/Shape/IR/Shape.h"
#include "mlir/IR/MLIRContext.h"

extern "C" {

// mlir::shape::ShapeType::get(ctx) → !shape.shape
static uint64_t mlir_dialect_shape_ir_shape_type_get(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir-dialect-shape-ir-shape-type-get",
                 "ctx must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<uint64_t>(
      mlir::shape::ShapeType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
          .getAsOpaquePointer());
}

// mlir::shape::SizeType::get(ctx) → !shape.size
static uint64_t mlir_dialect_shape_ir_size_type_get(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir-dialect-shape-ir-size-type-get", "ctx must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<uint64_t>(
      mlir::shape::SizeType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
          .getAsOpaquePointer());
}

// mlir::shape::WitnessType::get(ctx) → !shape.witness
static uint64_t mlir_dialect_shape_ir_witness_type_get(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir-dialect-shape-ir-witness-type-get",
                 "ctx must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<uint64_t>(
      mlir::shape::WitnessType::get(
          reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
          .getAsOpaquePointer());
}

} // extern "C"

namespace crest {

void registerDialectShapeBindings() {
  Sregister_symbol("mlir::shape::ShapeType::get",
                   (void*)::mlir_dialect_shape_ir_shape_type_get);
  Sregister_symbol("mlir::shape::SizeType::get",
                   (void*)::mlir_dialect_shape_ir_size_type_get);
  Sregister_symbol("mlir::shape::WitnessType::get",
                   (void*)::mlir_dialect_shape_ir_witness_type_get);
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/Shape/IR/Shape.h — type factory bindings.

#include "Shape.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Dialect/Shape/IR/Shape.h"
#include "mlir/IR/MLIRContext.h"

static void scheme_error(const char* who, const char* msg) {
  Scall2(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring(msg));
}

extern "C" {

// mlir::shape::ShapeType::get(ctx) → !shape.shape
uint64_t mlir_dialect_shape_shape_type_get(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir-dialect-shape-shape-type-get", "ctx must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<uint64_t>(
      mlir::shape::ShapeType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
          .getAsOpaquePointer());
}

// mlir::shape::SizeType::get(ctx) → !shape.size
uint64_t mlir_dialect_shape_size_type_get(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir-dialect-shape-size-type-get", "ctx must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  return reinterpret_cast<uint64_t>(
      mlir::shape::SizeType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
          .getAsOpaquePointer());
}

// mlir::shape::WitnessType::get(ctx) → !shape.witness
uint64_t mlir_dialect_shape_witness_type_get(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir-dialect-shape-witness-type-get", "ctx must not be null");
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
  Sregister_symbol("mlir_dialect_shape_shape_type_get",
                   (void*)::mlir_dialect_shape_shape_type_get);
  Sregister_symbol("mlir_dialect_shape_size_type_get",
                   (void*)::mlir_dialect_shape_size_type_get);
  Sregister_symbol("mlir_dialect_shape_witness_type_get",
                   (void*)::mlir_dialect_shape_witness_type_get);
}

} // namespace crest

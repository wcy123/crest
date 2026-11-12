/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Dialect.h

#include "Dialect.h"
#include "../Support/BuilderBinding.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Dialect.h"

namespace crest {

void registerIRDialectBindings() {
  // Dialect::materializeConstant(OpBuilder&, Attribute, Type, Location).
  // (builder dialect value type loc) → Operation* uptr, 0 when the dialect
  // makes none
  register_builder_binding(
      "mlir::Dialect::materializeConstant",
      [](mlir::OpBuilder& builder, uint64_t dialect_ptr, uint64_t value_ptr,
         uint64_t type_ptr, uint64_t loc_ptr) -> llvm::Expected<uint64_t> {
        if (!dialect_ptr) {
          return fail("mlir::Dialect::materializeConstant",
                      llvm::Twine("null dialect pointer"));
        }
        auto* dialect = reinterpret_cast<mlir::Dialect*>(dialect_ptr);
        auto value = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<const void*>(value_ptr));
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        return reinterpret_cast<uint64_t>(
            dialect->materializeConstant(builder, value, type, loc));
      });
}

} // namespace crest

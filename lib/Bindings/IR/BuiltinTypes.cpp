/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/BuiltinTypes.h — builtin type constructors and queries.

#include "BuiltinTypes.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Types.h"

namespace crest {

void registerIRBuiltinTypesBindings() {
  Sregister_symbol(
      "mlir::IndexType::get", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::IndexType::get", "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::IndexType::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::IntegerType::get<i64>", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::IntegerType::get<i64>",
                       "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::IntegerType::get(
                reinterpret_cast<mlir::MLIRContext*>(ctx_ptr), 64)
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::IntegerType::get<i1>", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::IntegerType::get<i1>",
                       "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::IntegerType::get(
                reinterpret_cast<mlir::MLIRContext*>(ctx_ptr), 1)
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::isa<RankedTensorType>", (void*)+[](uint64_t p) -> int {
        return (p && mlir::isa<mlir::RankedTensorType>(
                         mlir::Type::getFromOpaquePointer(
                             reinterpret_cast<const void*>(p))))
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "mlir::RankedTensorType::getRank",
      (void*)+[](uint64_t type_ptr) -> int64_t {
        if (!type_ptr) {
          scheme_error("mlir::RankedTensorType::getRank", "null type pointer");
        }
        auto t = mlir::dyn_cast<mlir::RankedTensorType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
        if (!t) {
          scheme_error("mlir::RankedTensorType::getRank",
                       "type is not a RankedTensorType");
        }
        return t.getRank();
      });
  Sregister_symbol(
      "mlir::RankedTensorType::getElementType",
      (void*)+[](uint64_t type_ptr) -> uint64_t {
        if (!type_ptr) {
          scheme_error("mlir::RankedTensorType::getElementType",
                       "null type pointer");
        }
        auto t = mlir::dyn_cast<mlir::RankedTensorType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
        if (!t) {
          scheme_error("mlir::RankedTensorType::getElementType",
                       "type is not a RankedTensorType");
        }
        return reinterpret_cast<uint64_t>(
            const_cast<void*>(t.getElementType().getAsOpaquePointer()));
      });
  Sregister_symbol(
      "mlir::RankedTensorType::getShape", (void*)+[](ptr p) -> ptr {
        if (!p) {
          scheme_error("mlir::RankedTensorType::getShape", "null type pointer");
        }
        auto t = llvm::dyn_cast<mlir::RankedTensorType>(
            mlir::Type::getFromOpaquePointer(p));
        if (!t) {
          scheme_error("mlir::RankedTensorType::getShape",
                       "not a RankedTensorType");
        }
        ptr list = Snil;
        for (int i = static_cast<int>(t.getShape().size()) - 1; i >= 0; --i) {
          list = Scons(Sinteger(t.getShape()[i]), list);
        }
        return list;
      });
  Sregister_symbol(
      "mlir::RankedTensorType::getEncoding",
      (void*)+[](uint64_t type_ptr) -> uint64_t {
        if (!type_ptr) {
          scheme_error("mlir::RankedTensorType::getEncoding",
                       "null type pointer");
        }
        auto t = mlir::dyn_cast<mlir::RankedTensorType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
        if (!t) {
          scheme_error("mlir::RankedTensorType::getEncoding",
                       "type is not a RankedTensorType");
        }
        mlir::Attribute enc = t.getEncoding();
        return enc ? reinterpret_cast<uint64_t>(enc.getAsOpaquePointer()) : 0;
      });
  Sregister_symbol(
      "mlir::RankedTensorType::cloneWithEncoding",
      (void*)+[](uint64_t type_ptr, uint64_t attr_ptr) -> uint64_t {
        if (!type_ptr) {
          scheme_error("mlir::RankedTensorType::cloneWithEncoding",
                       "null type pointer");
        }
        if (!attr_ptr) {
          scheme_error("mlir::RankedTensorType::cloneWithEncoding",
                       "null attribute pointer");
        }
        auto t = mlir::dyn_cast<mlir::RankedTensorType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
        if (!t) {
          scheme_error("mlir::RankedTensorType::cloneWithEncoding",
                       "type is not a RankedTensorType");
        }
        auto attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<const void*>(attr_ptr));
        return reinterpret_cast<uint64_t>(
            t.cloneWithEncoding(attr).getAsOpaquePointer());
      });
  // ── Type query functions (moved from BuiltinAttributes.cpp) ─────────────
  Sregister_symbol(
      "mlir::ShapedType::getElementType",
      (void*)+[](uint64_t type_ptr) -> uint64_t {
        if (!type_ptr) {
          scheme_error("mlir::ShapedType::getElementType", "null type pointer");
        }
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto st = mlir::dyn_cast<mlir::ShapedType>(type);
        if (!st) {
          scheme_error("mlir::ShapedType::getElementType",
                       "type is not a ShapedType");
        }
        return reinterpret_cast<uint64_t>(
            st.getElementType().getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::IntegerType::getWidth", (void*)+[](uint64_t type_ptr) -> uint64_t {
        if (!type_ptr) {
          scheme_error("mlir::IntegerType::getWidth", "null type pointer");
        }
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto it = mlir::dyn_cast<mlir::IntegerType>(type);
        if (!it) {
          scheme_error("mlir::IntegerType::getWidth",
                       "type is not an IntegerType");
        }
        return static_cast<uint64_t>(it.getWidth());
      });
  Sregister_symbol(
      "mlir::IntegerType::isUnsigned", (void*)+[](uint64_t p) -> int {
        if (!p) {
          scheme_error("mlir::IntegerType::isUnsigned", "null type pointer");
        }
        auto it = mlir::dyn_cast<mlir::IntegerType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!it) {
          scheme_error("mlir::IntegerType::isUnsigned", "not an IntegerType");
        }
        return it.isUnsigned() ? 1 : 0;
      });
}

} // namespace crest

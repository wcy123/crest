/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/BuiltinTypes.h — builtin type constructors and queries.

#include "BuiltinTypes.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/TypeRange.h"
#include "mlir/IR/Types.h"

namespace crest {

void registerIRBuiltinTypesBindings() {
  Sregister_symbol(
      "mlir::IndexType::get", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::IndexType::get", "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::IndexType::get(
                crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__))
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
                crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__), 64)
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
                crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__), 1)
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
          list = Scons(Sinteger(t.getShape()[static_cast<size_t>(i)]), list);
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

  Sregister_symbol(
      "mlir::IntegerType::get<i8>", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::IntegerType::get<i8>",
                       "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::IntegerType::get(
                crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__), 8)
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::IntegerType::get<i16>", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::IntegerType::get<i16>",
                       "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::IntegerType::get(
                crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__), 16)
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::IntegerType::get<i32>", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::IntegerType::get<i32>",
                       "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::IntegerType::get(
                crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__), 32)
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::IntegerType::get",
      (void*)+[](uint64_t ctx_ptr, int64_t width) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::IntegerType::get", "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::IntegerType::get(
                crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__),
                static_cast<unsigned>(width))
                .getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::Float16Type::get", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::Float16Type::get", "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::Float16Type::get(
                crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__))
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::BFloat16Type::get", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::BFloat16Type::get", "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::BFloat16Type::get(
                crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__))
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::Float32Type::get", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::Float32Type::get", "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::Float32Type::get(
                crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__))
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::Float64Type::get", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::Float64Type::get", "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::Float64Type::get(
                crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__))
                .getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::NoneType::get", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::NoneType::get", "null MLIRContext pointer");
        }
        return reinterpret_cast<uint64_t>(
            mlir::NoneType::get(
                crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__))
                .getAsOpaquePointer());
      });

#define CREST_ISA(TypeName)                                                    \
  Sregister_symbol(                                                            \
      "mlir::isa<" #TypeName ">", (void*)+[](uint64_t p) -> int {              \
        return (p &&                                                           \
                mlir::isa<mlir::TypeName>(mlir::Type::getFromOpaquePointer(    \
                    reinterpret_cast<const void*>(p))))                        \
                   ? 1                                                         \
                   : 0;                                                        \
      })

  // Singleton types (Float16/32/64, BFloat16, Index, None) have Scheme-level
  // isa predicates via (mlir-isa singleton-ptr) — no C++ binding needed.
  CREST_ISA(IntegerType); // parameterised — needs C++ isa
  CREST_ISA(FloatType);   // base float class — parameterised
  CREST_ISA(MemRefType);
  CREST_ISA(UnrankedMemRefType);
  CREST_ISA(UnrankedTensorType);
  CREST_ISA(VectorType);
  CREST_ISA(ComplexType);
#undef CREST_ISA

  Sregister_symbol(
      "mlir::FloatType::getWidth", (void*)+[](uint64_t p) -> int64_t {
        if (!p) {
          scheme_error("mlir::FloatType::getWidth", "null type pointer");
        }
        auto ft = mlir::dyn_cast<mlir::FloatType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!ft) {
          scheme_error("mlir::FloatType::getWidth", "not a FloatType");
        }
        return static_cast<int64_t>(ft.getWidth());
      });

  Sregister_symbol(
      "mlir::ComplexType::getElementType", (void*)+[](uint64_t p) -> uint64_t {
        if (!p) {
          scheme_error("mlir::ComplexType::getElementType",
                       "null type pointer");
        }
        auto ct = mlir::dyn_cast<mlir::ComplexType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!ct) {
          scheme_error("mlir::ComplexType::getElementType",
                       "not a ComplexType");
        }
        return reinterpret_cast<uint64_t>(
            ct.getElementType().getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::VectorType::getRank", (void*)+[](uint64_t p) -> int64_t {
        if (!p) {
          scheme_error("mlir::VectorType::getRank", "null type pointer");
        }
        auto vt = mlir::dyn_cast<mlir::VectorType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!vt) {
          scheme_error("mlir::VectorType::getRank", "not a VectorType");
        }
        return static_cast<int64_t>(vt.getRank());
      });
  Sregister_symbol(
      "mlir::VectorType::getElementType", (void*)+[](uint64_t p) -> uint64_t {
        if (!p) {
          scheme_error("mlir::VectorType::getElementType", "null type pointer");
        }
        auto vt = mlir::dyn_cast<mlir::VectorType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!vt) {
          scheme_error("mlir::VectorType::getElementType", "not a VectorType");
        }
        return reinterpret_cast<uint64_t>(
            vt.getElementType().getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::MemRefType::getElementType", (void*)+[](uint64_t p) -> uint64_t {
        if (!p) {
          scheme_error("mlir::MemRefType::getElementType", "null type pointer");
        }
        auto mt = mlir::dyn_cast<mlir::MemRefType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!mt) {
          scheme_error("mlir::MemRefType::getElementType", "not a MemRefType");
        }
        return reinterpret_cast<uint64_t>(
            mt.getElementType().getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::MemRefType::getMemorySpace", (void*)+[](uint64_t p) -> uint64_t {
        if (!p) {
          scheme_error("mlir::MemRefType::getMemorySpace", "null type pointer");
        }
        auto mt = mlir::dyn_cast<mlir::MemRefType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!mt) {
          scheme_error("mlir::MemRefType::getMemorySpace", "not a MemRefType");
        }
        mlir::Attribute ms = mt.getMemorySpace();
        return ms ? reinterpret_cast<uint64_t>(ms.getAsOpaquePointer()) : 0;
      });

  Sregister_symbol(
      "mlir::RankedTensorType::get",
      (void*)+[](ptr shape, uint64_t elem_type_ptr) -> uint64_t {
        auto elemType = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(elem_type_ptr));
        llvm::SmallVector<int64_t> dims;
        for (ptr cur = shape; cur != Snil; cur = Scdr(cur)) {
          dims.push_back(Sfixnum_value(Scar(cur)));
        }
        return reinterpret_cast<uint64_t>(
            mlir::RankedTensorType::get(dims, elemType).getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::UnrankedTensorType::get",
      (void*)+[](uint64_t elem_type_ptr) -> uint64_t {
        auto elemType = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(elem_type_ptr));
        return reinterpret_cast<uint64_t>(
            mlir::UnrankedTensorType::get(elemType).getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::FunctionType::get",
      (void*)+[](uint64_t ctx_ptr, ptr inputs, ptr results) -> uint64_t {
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__);
        llvm::SmallVector<mlir::Type> inputTypes, resultTypes;
        for (ptr cur = inputs; cur != Snil; cur = Scdr(cur)) {
          inputTypes.push_back(mlir::Type::getFromOpaquePointer(
              reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))));
        }
        for (ptr cur = results; cur != Snil; cur = Scdr(cur)) {
          resultTypes.push_back(mlir::Type::getFromOpaquePointer(
              reinterpret_cast<const void*>(Sunsigned64_value(Scar(cur)))));
        }
        return reinterpret_cast<uint64_t>(
            mlir::FunctionType::get(ctx, inputTypes, resultTypes)
                .getAsOpaquePointer());
      });
}

} // namespace crest

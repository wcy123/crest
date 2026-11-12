/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/BuiltinTypes.h — builtin type constructors and queries.

#include "BuiltinTypes.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/TypeRange.h"
#include "mlir/IR/Types.h"

namespace crest {

void registerIRBuiltinTypesBindings() {
  register_binding(
      "mlir::IndexType::get", [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::IndexType::get",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::IndexType::get(crest_lookup1).getAsOpaquePointer());
      });
  register_binding(
      "mlir::IntegerType::get<i64>",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::IntegerType::get<i64>",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::IntegerType::get(crest_lookup1, 64).getAsOpaquePointer());
      });
  register_binding(
      "mlir::IntegerType::get<i1>",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::IntegerType::get<i1>",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::IntegerType::get(crest_lookup1, 1).getAsOpaquePointer());
      });
  register_binding("mlir::isa<RankedTensorType>", [](uint64_t p) -> int {
    return (p &&
            mlir::isa<mlir::RankedTensorType>(mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(p))))
               ? 1
               : 0;
  });
  register_binding("mlir::RankedTensorType::getRank",
                   [](uint64_t type_ptr) -> llvm::Expected<int64_t> {
                     if (!type_ptr) {
                       return fail("mlir::RankedTensorType::getRank",
                                   llvm::Twine("null type pointer"));
                     }
                     auto t = mlir::dyn_cast<mlir::RankedTensorType>(
                         mlir::Type::getFromOpaquePointer(
                             reinterpret_cast<const void*>(type_ptr)));
                     if (!t) {
                       return fail(
                           "mlir::RankedTensorType::getRank",
                           llvm::Twine("type is not a RankedTensorType"));
                     }
                     return t.getRank();
                   });
  register_binding(
      "mlir::RankedTensorType::getElementType",
      [](uint64_t type_ptr) -> llvm::Expected<uint64_t> {
        if (!type_ptr) {
          return fail("mlir::RankedTensorType::getElementType",
                      llvm::Twine("null type pointer"));
        }
        auto t = mlir::dyn_cast<mlir::RankedTensorType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
        if (!t) {
          return fail("mlir::RankedTensorType::getElementType",
                      llvm::Twine("type is not a RankedTensorType"));
        }
        return reinterpret_cast<uint64_t>(
            const_cast<void*>(t.getElementType().getAsOpaquePointer()));
      });
  register_binding(
      "mlir::RankedTensorType::getShape", [](ptr p) -> llvm::Expected<ptr> {
        if (!p) {
          return fail("mlir::RankedTensorType::getShape",
                      llvm::Twine("null type pointer"));
        }
        auto t = llvm::dyn_cast<mlir::RankedTensorType>(
            mlir::Type::getFromOpaquePointer(p));
        if (!t) {
          return fail("mlir::RankedTensorType::getShape",
                      llvm::Twine("not a RankedTensorType"));
        }
        ptr list = Snil;
        for (int i = static_cast<int>(t.getShape().size()) - 1; i >= 0; --i) {
          list = Scons(Sinteger(t.getShape()[static_cast<size_t>(i)]), list);
        }
        return list;
      });
  register_binding(
      "mlir::ShapedType::getShape", [](ptr p) -> llvm::Expected<ptr> {
        if (!p) {
          return fail("mlir::ShapedType::getShape",
                      llvm::Twine("null type pointer"));
        }
        auto t = mlir::dyn_cast<mlir::ShapedType>(
            mlir::Type::getFromOpaquePointer(p));
        if (!t) {
          return fail("mlir::ShapedType::getShape",
                      llvm::Twine("not a ShapedType"));
        }
        ptr list = Snil;
        auto shape = t.getShape();
        for (int i = static_cast<int>(shape.size()) - 1; i >= 0; --i) {
          list = Scons(Sinteger(shape[static_cast<size_t>(i)]), list);
        }
        return list;
      });
  register_binding(
      "mlir::RankedTensorType::getEncoding",
      [](uint64_t type_ptr) -> llvm::Expected<uint64_t> {
        if (!type_ptr) {
          return fail("mlir::RankedTensorType::getEncoding",
                      llvm::Twine("null type pointer"));
        }
        auto t = mlir::dyn_cast<mlir::RankedTensorType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
        if (!t) {
          return fail("mlir::RankedTensorType::getEncoding",
                      llvm::Twine("type is not a RankedTensorType"));
        }
        mlir::Attribute enc = t.getEncoding();
        return enc ? reinterpret_cast<uint64_t>(enc.getAsOpaquePointer()) : 0;
      });
  register_binding(
      "mlir::RankedTensorType::cloneWithEncoding",
      [](uint64_t type_ptr, uint64_t attr_ptr) -> llvm::Expected<uint64_t> {
        if (!type_ptr) {
          return fail("mlir::RankedTensorType::cloneWithEncoding",
                      llvm::Twine("null type pointer"));
        }
        if (!attr_ptr) {
          return fail("mlir::RankedTensorType::cloneWithEncoding",
                      llvm::Twine("null attribute pointer"));
        }
        auto t = mlir::dyn_cast<mlir::RankedTensorType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
        if (!t) {
          return fail("mlir::RankedTensorType::cloneWithEncoding",
                      llvm::Twine("type is not a RankedTensorType"));
        }
        auto attr = mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<const void*>(attr_ptr));
        return reinterpret_cast<uint64_t>(
            t.cloneWithEncoding(attr).getAsOpaquePointer());
      });
  register_binding("mlir::ShapedType::getElementType",
                   [](uint64_t type_ptr) -> llvm::Expected<uint64_t> {
                     if (!type_ptr) {
                       return fail("mlir::ShapedType::getElementType",
                                   llvm::Twine("null type pointer"));
                     }
                     auto type = mlir::Type::getFromOpaquePointer(
                         reinterpret_cast<const void*>(type_ptr));
                     auto st = mlir::dyn_cast<mlir::ShapedType>(type);
                     if (!st) {
                       return fail("mlir::ShapedType::getElementType",
                                   llvm::Twine("type is not a ShapedType"));
                     }
                     return reinterpret_cast<uint64_t>(
                         st.getElementType().getAsOpaquePointer());
                   });
  register_binding("mlir::IntegerType::getWidth",
                   [](uint64_t type_ptr) -> llvm::Expected<uint64_t> {
                     if (!type_ptr) {
                       return fail("mlir::IntegerType::getWidth",
                                   llvm::Twine("null type pointer"));
                     }
                     auto type = mlir::Type::getFromOpaquePointer(
                         reinterpret_cast<const void*>(type_ptr));
                     auto it = mlir::dyn_cast<mlir::IntegerType>(type);
                     if (!it) {
                       return fail("mlir::IntegerType::getWidth",
                                   llvm::Twine("type is not an IntegerType"));
                     }
                     return static_cast<uint64_t>(it.getWidth());
                   });
  register_binding(
      "mlir::IntegerType::isUnsigned", [](uint64_t p) -> llvm::Expected<int> {
        if (!p) {
          return fail("mlir::IntegerType::isUnsigned",
                      llvm::Twine("null type pointer"));
        }
        auto it = mlir::dyn_cast<mlir::IntegerType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!it) {
          return fail("mlir::IntegerType::isUnsigned",
                      llvm::Twine("not an IntegerType"));
        }
        return it.isUnsigned() ? 1 : 0;
      });

  register_binding(
      "mlir::IntegerType::get<i8>",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::IntegerType::get<i8>",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::IntegerType::get(crest_lookup1, 8).getAsOpaquePointer());
      });
  register_binding(
      "mlir::IntegerType::get<i16>",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::IntegerType::get<i16>",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::IntegerType::get(crest_lookup1, 16).getAsOpaquePointer());
      });
  register_binding(
      "mlir::IntegerType::get<i32>",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::IntegerType::get<i32>",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::IntegerType::get(crest_lookup1, 32).getAsOpaquePointer());
      });
  register_binding(
      "mlir::IntegerType::get",
      [](uint64_t ctx_ptr, int64_t width) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::IntegerType::get",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::IntegerType::get(crest_lookup1, static_cast<unsigned>(width))
                .getAsOpaquePointer());
      });

  register_binding(
      "mlir::Float16Type::get",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::Float16Type::get",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::Float16Type::get(crest_lookup1).getAsOpaquePointer());
      });
  register_binding(
      "mlir::BFloat16Type::get",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::BFloat16Type::get",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::BFloat16Type::get(crest_lookup1).getAsOpaquePointer());
      });
  register_binding(
      "mlir::Float32Type::get",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::Float32Type::get",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::Float32Type::get(crest_lookup1).getAsOpaquePointer());
      });
  register_binding(
      "mlir::Float64Type::get",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::Float64Type::get",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::Float64Type::get(crest_lookup1).getAsOpaquePointer());
      });

  register_binding(
      "mlir::NoneType::get", [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::NoneType::get",
                      llvm::Twine("null MLIRContext pointer"));
        }
        CREST_TRY(crest_lookup1,
                  crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::NoneType::get(crest_lookup1).getAsOpaquePointer());
      });

#define CREST_ISA(TypeName)                                                    \
  register_binding("mlir::isa<" #TypeName ">", [](uint64_t p) -> int {         \
    return (p && mlir::isa<mlir::TypeName>(mlir::Type::getFromOpaquePointer(   \
                     reinterpret_cast<const void*>(p))))                       \
               ? 1                                                             \
               : 0;                                                            \
  })

  // Singleton types (Float16/32/64, BFloat16, Index, None) have Scheme-level
  // isa predicates via (mlir-isa singleton-ptr) — no C++ binding needed.
  CREST_ISA(IntegerType); // parameterised — needs C++ isa
  CREST_ISA(FloatType);   // base float class — parameterised
  CREST_ISA(MemRefType);
  CREST_ISA(UnrankedMemRefType);
  CREST_ISA(UnrankedTensorType);
  CREST_ISA(TensorType);
  CREST_ISA(VectorType);
  CREST_ISA(ComplexType);
#undef CREST_ISA

  // The element type of a ranked or unranked tensor.
  register_binding("mlir::TensorType::getElementType",
                   [](uint64_t p) -> llvm::Expected<uint64_t> {
                     auto tensor =
                         p ? mlir::dyn_cast<mlir::TensorType>(
                                 mlir::Type::getFromOpaquePointer(
                                     reinterpret_cast<const void*>(p)))
                           : mlir::TensorType();
                     if (!tensor) {
                       return fail("mlir::TensorType::getElementType",
                                   llvm::Twine("not a tensor type"));
                     }
                     return reinterpret_cast<uint64_t>(
                         tensor.getElementType().getAsOpaquePointer());
                   });

  register_binding(
      "mlir::FloatType::getWidth", [](uint64_t p) -> llvm::Expected<int64_t> {
        if (!p) {
          return fail("mlir::FloatType::getWidth",
                      llvm::Twine("null type pointer"));
        }
        auto ft = mlir::dyn_cast<mlir::FloatType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!ft) {
          return fail("mlir::FloatType::getWidth",
                      llvm::Twine("not a FloatType"));
        }
        return static_cast<int64_t>(ft.getWidth());
      });

  register_binding(
      "mlir::ComplexType::getElementType",
      [](uint64_t p) -> llvm::Expected<uint64_t> {
        if (!p) {
          return fail("mlir::ComplexType::getElementType",
                      llvm::Twine("null type pointer"));
        }
        auto ct = mlir::dyn_cast<mlir::ComplexType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!ct) {
          return fail("mlir::ComplexType::getElementType",
                      llvm::Twine("not a ComplexType"));
        }
        return reinterpret_cast<uint64_t>(
            ct.getElementType().getAsOpaquePointer());
      });

  register_binding(
      "mlir::VectorType::getRank", [](uint64_t p) -> llvm::Expected<int64_t> {
        if (!p) {
          return fail("mlir::VectorType::getRank",
                      llvm::Twine("null type pointer"));
        }
        auto vt = mlir::dyn_cast<mlir::VectorType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!vt) {
          return fail("mlir::VectorType::getRank",
                      llvm::Twine("not a VectorType"));
        }
        return static_cast<int64_t>(vt.getRank());
      });
  register_binding(
      "mlir::VectorType::getElementType",
      [](uint64_t p) -> llvm::Expected<uint64_t> {
        if (!p) {
          return fail("mlir::VectorType::getElementType",
                      llvm::Twine("null type pointer"));
        }
        auto vt = mlir::dyn_cast<mlir::VectorType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!vt) {
          return fail("mlir::VectorType::getElementType",
                      llvm::Twine("not a VectorType"));
        }
        return reinterpret_cast<uint64_t>(
            vt.getElementType().getAsOpaquePointer());
      });

  register_binding(
      "mlir::MemRefType::getElementType",
      [](uint64_t p) -> llvm::Expected<uint64_t> {
        if (!p) {
          return fail("mlir::MemRefType::getElementType",
                      llvm::Twine("null type pointer"));
        }
        auto mt = mlir::dyn_cast<mlir::MemRefType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!mt) {
          return fail("mlir::MemRefType::getElementType",
                      llvm::Twine("not a MemRefType"));
        }
        return reinterpret_cast<uint64_t>(
            mt.getElementType().getAsOpaquePointer());
      });
  register_binding(
      "mlir::MemRefType::getMemorySpace",
      [](uint64_t p) -> llvm::Expected<uint64_t> {
        if (!p) {
          return fail("mlir::MemRefType::getMemorySpace",
                      llvm::Twine("null type pointer"));
        }
        auto mt = mlir::dyn_cast<mlir::MemRefType>(
            mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(p)));
        if (!mt) {
          return fail("mlir::MemRefType::getMemorySpace",
                      llvm::Twine("not a MemRefType"));
        }
        mlir::Attribute ms = mt.getMemorySpace();
        return ms ? reinterpret_cast<uint64_t>(ms.getAsOpaquePointer()) : 0;
      });

  register_binding(
      "mlir::RankedTensorType::get",
      [](ptr shape, uint64_t elem_type_ptr) -> uint64_t {
        auto elemType = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(elem_type_ptr));
        llvm::SmallVector<int64_t> dims;
        for (ptr cur = shape; cur != Snil; cur = Scdr(cur)) {
          dims.push_back(Sfixnum_value(Scar(cur)));
        }
        return reinterpret_cast<uint64_t>(
            mlir::RankedTensorType::get(dims, elemType).getAsOpaquePointer());
      });

  register_binding(
      "mlir::UnrankedTensorType::get", [](uint64_t elem_type_ptr) -> uint64_t {
        auto elemType = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(elem_type_ptr));
        return reinterpret_cast<uint64_t>(
            mlir::UnrankedTensorType::get(elemType).getAsOpaquePointer());
      });

  register_binding(
      "mlir::FunctionType::get",
      [](uint64_t ctx_ptr, ptr inputs,
         ptr results) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::try_as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
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

  // mlir::FunctionType::getInputs (uptr type) -> list of Type
  // mlir::FunctionType::getResults (uptr type) -> list of Type
  register_binding(
      "mlir::FunctionType::getInputs", [](uint64_t type_ptr) -> ptr {
        auto type =
            mlir::cast<mlir::FunctionType>(mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
        ptr list = Snil;
        for (auto it = type.getInputs().rbegin(); it != type.getInputs().rend();
             ++it) {
          list = Scons(
              Sunsigned64(reinterpret_cast<uint64_t>(it->getAsOpaquePointer())),
              list);
        }
        return list;
      });
  register_binding(
      "mlir::FunctionType::getResults", [](uint64_t type_ptr) -> ptr {
        auto type =
            mlir::cast<mlir::FunctionType>(mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
        ptr list = Snil;
        for (auto it = type.getResults().rbegin();
             it != type.getResults().rend(); ++it) {
          list = Scons(
              Sunsigned64(reinterpret_cast<uint64_t>(it->getAsOpaquePointer())),
              list);
        }
        return list;
      });
}

} // namespace crest

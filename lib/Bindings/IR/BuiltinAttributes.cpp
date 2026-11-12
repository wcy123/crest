/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/BuiltinAttributes.h — attribute construction and inspection.

#include "BuiltinAttributes.h"
#include "../Support/ArrayRef.h"
#include "../Support/Logging.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/AsmParser/AsmParser.h"
#include "mlir/IR/AsmState.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include <limits>
#include <string>

namespace crest {

void registerIRBuiltinAttributesBindings() {

  register_binding(
      "mlir::IntegerAttr::get<i64>",
      [](uint64_t ctx_ptr, ptr value) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            mlir::IntegerAttr::get(mlir::IntegerType::get(ctx, 64),
                                   Sinteger64_value(value))
                .getAsOpaquePointer());
      });

  register_binding(
      "mlir::IntegerAttr::get<i8>",
      [](uint64_t ctx_ptr, ptr value) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            mlir::IntegerAttr::get(mlir::IntegerType::get(ctx, 8),
                                   Sinteger64_value(value))
                .getAsOpaquePointer());
      });

  register_binding(
      "mlir::IntegerAttr::get<i16>",
      [](uint64_t ctx_ptr, ptr value) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            mlir::IntegerAttr::get(mlir::IntegerType::get(ctx, 16),
                                   Sinteger64_value(value))
                .getAsOpaquePointer());
      });

  register_binding(
      "mlir::IntegerAttr::get<i32>",
      [](uint64_t ctx_ptr, ptr value) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            mlir::IntegerAttr::get(mlir::IntegerType::get(ctx, 32),
                                   Sinteger64_value(value))
                .getAsOpaquePointer());
      });

  register_binding(
      "mlir::IntegerAttr::get<index>",
      [](uint64_t ctx_ptr, ptr value) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            mlir::IntegerAttr::get(mlir::IndexType::get(ctx),
                                   Sinteger64_value(value))
                .getAsOpaquePointer());
      });

  register_binding(
      "mlir::FloatAttr::get<f32>",
      [](uint64_t ctx_ptr, ptr value) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            mlir::FloatAttr::get(mlir::Float32Type::get(ctx),
                                 static_cast<float>(Sflonum_value(value)))
                .getAsOpaquePointer());
      });

  register_binding(
      "mlir::DenseI32ArrayAttr::get",
      [](uint64_t ctx_ptr, ptr value) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        llvm::SmallVector<int32_t> vec;
        if (Svectorp(value)) {
          iptr n = Svector_length(value);
          for (iptr i = 0; i < n; ++i) {
            vec.push_back(
                static_cast<int32_t>(Sfixnum_value(Svector_ref(value, i))));
          }
        } else if (Spairp(value) || value == Snil) {
          for (ptr cur = value; cur != Snil; cur = Scdr(cur)) {
            vec.push_back(static_cast<int32_t>(Sfixnum_value(Scar(cur))));
          }
        } else {
          return fail("mlir::DenseI32ArrayAttr::get",
                      "value must be a Scheme list or vector");
        }
        return reinterpret_cast<uint64_t>(
            mlir::DenseI32ArrayAttr::get(ctx, vec).getAsOpaquePointer());
      });

  register_binding(
      "mlir::DenseI64ArrayAttr::get",
      [](uint64_t ctx_ptr, ptr value) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        llvm::SmallVector<int64_t> vec;
        if (Svectorp(value)) {
          iptr n = Svector_length(value);
          for (iptr i = 0; i < n; ++i) {
            vec.push_back(Sinteger64_value(Svector_ref(value, i)));
          }
        } else if (Spairp(value) || value == Snil) {
          for (ptr cur = value; cur != Snil; cur = Scdr(cur)) {
            vec.push_back(Sinteger64_value(Scar(cur)));
          }
        } else {
          return fail("mlir::DenseI64ArrayAttr::get",
                      "value must be a Scheme list or vector");
        }
        return reinterpret_cast<uint64_t>(
            mlir::DenseI64ArrayAttr::get(ctx, vec).getAsOpaquePointer());
      });

  // Scheme list or vector of integers; each element is narrowed to the element
  // type.
  register_binding(
      "mlir::DenseI8ArrayAttr::get",
      [](uint64_t ctx_ptr, ptr value) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        llvm::SmallVector<int8_t> vec;
        for (int64_t v : convert_to_cpp<llvm::SmallVector<int64_t>>(value)) {
          vec.push_back(static_cast<int8_t>(v));
        }
        return reinterpret_cast<uint64_t>(
            mlir::DenseI8ArrayAttr::get(ctx, vec).getAsOpaquePointer());
      });

  register_binding(
      "mlir::DenseI16ArrayAttr::get",
      [](uint64_t ctx_ptr, ptr value) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        llvm::SmallVector<int16_t> vec;
        for (int64_t v : convert_to_cpp<llvm::SmallVector<int64_t>>(value)) {
          vec.push_back(static_cast<int16_t>(v));
        }
        return reinterpret_cast<uint64_t>(
            mlir::DenseI16ArrayAttr::get(ctx, vec).getAsOpaquePointer());
      });

  register_binding(
      "mlir::parseAttribute",
      [](uint64_t ctx_ptr, const char* spec) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        mlir::Attribute attr = mlir::parseAttribute(spec, ctx);
        if (!attr) {
          return fail("mlir::parseAttribute",
                      llvm::Twine("failed to parse attribute: ") + " " +
                          llvm::Twine(spec));
          return 0;
        }
        return reinterpret_cast<uint64_t>(attr.getAsOpaquePointer());
      });

  register_binding(
      "mlir::DenseResourceElementsAttr::get",
      [](uint64_t /*ctx_ptr*/, ptr value) -> llvm::Expected<uint64_t> {
        auto result_type_ptr = Sunsigned64_value(Scar(value));
        ptr skey = Scar(Scdr(value));
        iptr klen = Sstring_length(skey);
        int64_t data_addr = Sinteger64_value(Scar(Scdr(Scdr(value))));
        int64_t data_size = Sinteger64_value(Scar(Scdr(Scdr(Scdr(value)))));
        auto baseType = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(result_type_ptr));
        auto resultType = llvm::dyn_cast<mlir::RankedTensorType>(baseType);
        if (!resultType) {
          return fail("mlir::DenseResourceElementsAttr::get",
                      "result-type is not a RankedTensorType");
        }
        std::string key_str(static_cast<size_t>(klen), '\0');
        for (iptr i = 0; i < klen; ++i) {
          key_str[static_cast<size_t>(i)] =
              static_cast<char>(Sstring_ref(skey, i));
        }
        llvm::ArrayRef<char> data = {
            reinterpret_cast<const char*>(static_cast<uintptr_t>(data_addr)),
            static_cast<size_t>(data_size)};
        return reinterpret_cast<uint64_t>(
            mlir::DenseResourceElementsAttr::get(
                resultType, key_str.c_str(),
                mlir::UnmanagedAsmResourceBlob::allocateInferAlign(data))
                .getAsOpaquePointer());
      });

  register_binding(
      "mlir::UnitAttr::get", [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        CREST_TRY(crest_lookup1,
                  crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));

        return reinterpret_cast<uint64_t>(
            mlir::UnitAttr::get(crest_lookup1).getAsOpaquePointer());
      });

  register_binding("mlir::isa<IntegerAttr>", [](uint64_t p) -> int {
    return (p &&
            mlir::isa<mlir::IntegerAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p))))
               ? 1
               : 0;
  });

  register_binding("mlir::isa<FloatAttr>", [](uint64_t p) -> int {
    return (p &&
            mlir::isa<mlir::FloatAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p))))
               ? 1
               : 0;
  });

  register_binding(
      "mlir::StringAttr::get",
      [](uint64_t ctx_ptr, const char* str) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            mlir::StringAttr::get(ctx, str).getAsOpaquePointer());
      });
  // Variant with explicit length — required when the string contains NUL bytes.
  register_binding(
      "mlir::StringAttr::get/len",
      [](uint64_t ctx_ptr, const char* str,
         uint64_t len) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            mlir::StringAttr::get(ctx, llvm::StringRef(str, len))
                .getAsOpaquePointer());
      });

  register_binding("mlir::DenseElementsAttr::get<f64>",
                   [](uint64_t type_ptr, ptr values) -> uint64_t {
                     auto type = mlir::Type::getFromOpaquePointer(
                         reinterpret_cast<const void*>(type_ptr));
                     auto tensorType = mlir::cast<mlir::ShapedType>(type);
                     llvm::SmallVector<double> vals;
                     for (ptr cur = values; cur != Snil; cur = Scdr(cur)) {
                       ptr v = Scar(cur);
                       if (Sflonump(v)) {
                         vals.push_back(Sflonum_value(v));
                       } else {
                         vals.push_back(static_cast<double>(Sfixnum_value(v)));
                       }
                     }
                     return reinterpret_cast<uint64_t>(
                         mlir::DenseElementsAttr::get(
                             tensorType, llvm::ArrayRef<double>(vals))
                             .getAsOpaquePointer());
                   });

  register_binding("mlir::TypeAttr::get", [](uint64_t type_ptr) -> uint64_t {
    auto type = mlir::Type::getFromOpaquePointer(
        reinterpret_cast<const void*>(type_ptr));
    return reinterpret_cast<uint64_t>(
        mlir::TypeAttr::get(type).getAsOpaquePointer());
  });

  register_binding(
      "mlir::TypeAttr::getValue", [](uint64_t attr_ptr) -> uint64_t {
        auto ta =
            mlir::cast<mlir::TypeAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
        return reinterpret_cast<uint64_t>(ta.getValue().getAsOpaquePointer());
      });

  /// map_ptr: AffineMap opaque pointer (see mlir/IR/AffineMap.h)
  register_binding("mlir::AffineMapAttr::get",
                   [](uint64_t map_ptr) -> uint64_t {
                     auto map = mlir::AffineMap::getFromOpaquePointer(
                         reinterpret_cast<const void*>(map_ptr));
                     return reinterpret_cast<uint64_t>(
                         mlir::AffineMapAttr::get(map).getAsOpaquePointer());
                   });

  register_binding(
      "mlir::AffineMapAttr::getValue", [](uint64_t attr_ptr) -> uint64_t {
        auto ama = mlir::cast<mlir::AffineMapAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
        return reinterpret_cast<uint64_t>(ama.getValue().getAsOpaquePointer());
      });

  register_binding("mlir::isa<StringAttr>", [](uint64_t p) -> int {
    return (p &&
            mlir::isa<mlir::StringAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p))))
               ? 1
               : 0;
  });

  register_binding("mlir::isa<DenseI32ArrayAttr>", [](uint64_t p) -> int {
    return (p && mlir::isa<mlir::DenseI32ArrayAttr>(
                     mlir::Attribute::getFromOpaquePointer(
                         reinterpret_cast<const void*>(p))))
               ? 1
               : 0;
  });

  register_binding("mlir::isa<DenseElementsAttr>", [](uint64_t p) -> int {
    return (p && mlir::isa<mlir::DenseElementsAttr>(
                     mlir::Attribute::getFromOpaquePointer(
                         reinterpret_cast<const void*>(p))))
               ? 1
               : 0;
  });

  register_binding("mlir::DenseElementsAttr::isSplat", [](uint64_t p) -> int {
    if (!p) {
      return 0;
    }
    auto dense = mlir::dyn_cast<mlir::DenseElementsAttr>(
        mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<const void*>(p)));
    return (dense && dense.isSplat()) ? 1 : 0;
  });

  // mlir::isa<FloatAttr>.f32 is the same check as mlir::isa<FloatAttr>.
  register_binding("mlir::isa<FloatAttr>.f32", [](uint64_t p) -> int {
    return (p &&
            mlir::isa<mlir::FloatAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p))))
               ? 1
               : 0;
  });

  register_binding(
      "mlir::IntegerAttr::getValue", [](uint64_t p) -> llvm::Expected<ptr> {
        if (!p) {
          return fail("mlir::IntegerAttr::getValue",
                      llvm::Twine("null attribute pointer"));
        }
        auto iattr = mlir::dyn_cast<mlir::IntegerAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!iattr) {
          return fail("mlir::IntegerAttr::getValue",
                      llvm::Twine("attribute is not an IntegerAttr"));
        }
        return Sinteger64(iattr.getValue().getSExtValue());
      });

  register_binding("mlir::FloatAttr::getValueAsDouble",
                   [](uint64_t p) -> llvm::Expected<ptr> {
                     if (!p) {
                       return fail("mlir::FloatAttr::getValueAsDouble",
                                   llvm::Twine("null attribute pointer"));
                     }
                     auto fattr = mlir::dyn_cast<mlir::FloatAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<const void*>(p)));
                     if (!fattr) {
                       return fail("mlir::FloatAttr::getValueAsDouble",
                                   llvm::Twine("attribute is not a FloatAttr"));
                     }
                     return Sflonum(fattr.getValueAsDouble());
                   });

  // getValueAsDouble.f32 is identical to getValueAsDouble.
  register_binding("mlir::FloatAttr::getValueAsDouble.f32",
                   [](uint64_t p) -> llvm::Expected<ptr> {
                     if (!p) {
                       return fail("mlir::FloatAttr::getValueAsDouble.f32",
                                   llvm::Twine("null attribute pointer"));
                     }
                     auto fattr = mlir::dyn_cast<mlir::FloatAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<const void*>(p)));
                     if (!fattr) {
                       return fail("mlir::FloatAttr::getValueAsDouble.f32",
                                   llvm::Twine("attribute is not a FloatAttr"));
                     }
                     return Sflonum(fattr.getValueAsDouble());
                   });

  // mlir::DenseI64ArrayAttr::asArrayRef (uptr attr) → list of integers.
  // A copy of the elements as a Scheme list: the ArrayRef of C++ is a view of
  // the attribute's storage, and a view handed to Scheme as a heap object
  // leaked whenever the caller forgot to free it (the old intoArrayRef).
  register_binding("mlir::DenseI64ArrayAttr::asArrayRef",
                   [](uint64_t p) -> llvm::Expected<ptr> {
                     if (!p) {
                       return fail("mlir::DenseI64ArrayAttr::asArrayRef",
                                   llvm::Twine("null attribute pointer"));
                     }
                     auto arr = mlir::dyn_cast<mlir::DenseI64ArrayAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<const void*>(p)));
                     if (!arr) {
                       return fail(
                           "mlir::DenseI64ArrayAttr::asArrayRef",
                           llvm::Twine("attribute is not a DenseI64ArrayAttr"));
                     }
                     llvm::ArrayRef<int64_t> values = arr.asArrayRef();
                     ptr list = Snil;
                     for (size_t i = values.size(); i-- > 0;) {
                       list = Scons(Sinteger64(values[i]), list);
                     }
                     return list;
                   });

  // mlir::DenseI32ArrayAttr::asArrayRef (uptr attr) → list of integers; see the
  // i64 one above.
  register_binding("mlir::DenseI32ArrayAttr::asArrayRef",
                   [](uint64_t p) -> llvm::Expected<ptr> {
                     if (!p) {
                       return fail("mlir::DenseI32ArrayAttr::asArrayRef",
                                   llvm::Twine("null attribute pointer"));
                     }
                     auto arr = mlir::dyn_cast<mlir::DenseI32ArrayAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<const void*>(p)));
                     if (!arr) {
                       return fail(
                           "mlir::DenseI32ArrayAttr::asArrayRef",
                           llvm::Twine("attribute is not a DenseI32ArrayAttr"));
                     }
                     llvm::ArrayRef<int32_t> values = arr.asArrayRef();
                     ptr list = Snil;
                     for (size_t i = values.size(); i-- > 0;) {
                       list = Scons(Sinteger32(values[i]), list);
                     }
                     return list;
                   });

  register_binding(
      "mlir::DenseElementsAttr::getSplatValue<APFloat>",
      [](uint64_t p) -> llvm::Expected<ptr> {
        if (!p) {
          return fail("mlir::DenseElementsAttr::getSplatValue<APFloat>",
                      llvm::Twine("null pointer"));
        }
        auto d = mlir::dyn_cast<mlir::DenseFPElementsAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!d) {
          return fail("mlir::DenseElementsAttr::getSplatValue<APFloat>",
                      llvm::Twine("not DenseFPElementsAttr"));
        }
        if (!d.isSplat()) {
          return fail("mlir::DenseElementsAttr::getSplatValue<APFloat>",
                      llvm::Twine("not a splat"));
        }
        return Sflonum((*d.begin()).convertToDouble());
      });

  register_binding(
      "mlir::DenseElementsAttr::getSplatValue<APInt>",
      [](uint64_t p) -> llvm::Expected<ptr> {
        if (!p) {
          return fail("mlir::DenseElementsAttr::getSplatValue<APInt>",
                      llvm::Twine("null pointer"));
        }
        auto d = mlir::dyn_cast<mlir::DenseIntElementsAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!d) {
          return fail("mlir::DenseElementsAttr::getSplatValue<APInt>",
                      llvm::Twine("not DenseIntElementsAttr"));
        }
        if (!d.isSplat()) {
          return fail("mlir::DenseElementsAttr::getSplatValue<APInt>",
                      llvm::Twine("not a splat"));
        }
        return Sinteger64((*d.begin()).getSExtValue());
      });

  register_binding(
      "mlir::DenseI32ArrayAttr::toVector",
      [](uint64_t p) -> llvm::Expected<ptr> {
        if (!p) {
          return fail("mlir::DenseI32ArrayAttr::toVector",
                      llvm::Twine("null attribute pointer"));
        }
        auto arr = mlir::dyn_cast<mlir::DenseI32ArrayAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!arr) {
          return fail("mlir::DenseI32ArrayAttr::toVector",
                      llvm::Twine("attribute is not a DenseI32ArrayAttr"));
        }
        auto vals = arr.asArrayRef();
        ptr v = Smake_vector(static_cast<iptr>(vals.size()), Sfixnum(0));
        for (iptr i = 0; i < static_cast<iptr>(vals.size()); ++i) {
          Svector_set(v, i, Sfixnum(vals[static_cast<size_t>(i)]));
        }
        return v;
      });

  register_binding(
      "mlir::DenseI64ArrayAttr::toVector",
      [](uint64_t p) -> llvm::Expected<ptr> {
        if (!p) {
          return fail("mlir::DenseI64ArrayAttr::toVector",
                      llvm::Twine("null attribute pointer"));
        }
        auto arr = mlir::dyn_cast<mlir::DenseI64ArrayAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!arr) {
          return fail("mlir::DenseI64ArrayAttr::toVector",
                      llvm::Twine("attribute is not a DenseI64ArrayAttr"));
        }
        auto vals = arr.asArrayRef();
        ptr v = Smake_vector(static_cast<iptr>(vals.size()), Sfixnum(0));
        for (iptr i = 0; i < static_cast<iptr>(vals.size()); ++i) {
          Svector_set(v, i, Sinteger(vals[static_cast<size_t>(i)]));
        }
        return v;
      });

  register_binding(
      "mlir::DenseElementsAttr::getType", [](uint64_t attr_ptr) -> uint64_t {
        auto attr = mlir::cast<mlir::DenseElementsAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<void*>(attr_ptr)));
        return reinterpret_cast<uint64_t>(attr.getType().getAsOpaquePointer());
      });

  register_binding("mlir::DenseElementsAttr::reshape",
                   [](uint64_t attr_ptr, uint64_t type_ptr) -> uint64_t {
                     auto attr = mlir::cast<mlir::DenseElementsAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<void*>(attr_ptr)));
                     auto shaped = mlir::cast<mlir::ShapedType>(
                         mlir::Type::getFromOpaquePointer(
                             reinterpret_cast<void*>(type_ptr)));
                     return reinterpret_cast<uint64_t>(
                         attr.reshape(shaped).getAsOpaquePointer());
                   });

  register_binding(
      "mlir::FloatAttr::get<f64>",
      [](uint64_t ctx_ptr, double val) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        auto attr = mlir::FloatAttr::get(mlir::Float64Type::get(ctx), val);
        return reinterpret_cast<uint64_t>(attr.getAsOpaquePointer());
      });

  register_binding("mlir::DenseElementsAttr::getNumElements",
                   [](uint64_t attr_ptr) -> uint64_t {
                     auto attr = mlir::cast<mlir::DenseElementsAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<void*>(attr_ptr)));
                     return static_cast<uint64_t>(attr.getNumElements());
                   });

  // Returns the FloatAttr at linear index idx from a f64 DenseElementsAttr.
  register_binding("mlir::DenseElementsAttr::getValueAt<f64>",
                   [](uint64_t attr_ptr, uint64_t idx) -> uint64_t {
                     auto attr = mlir::cast<mlir::DenseElementsAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<void*>(attr_ptr)));
                     auto it = attr.value_begin<mlir::FloatAttr>();
                     std::advance(it, static_cast<ptrdiff_t>(idx));
                     mlir::FloatAttr fa = *it;
                     return reinterpret_cast<uint64_t>(fa.getAsOpaquePointer());
                   });

  // mlir::ArrayAttr::get — create an ArrayAttr from a Scheme list of Attr
  // uptrss. (ctx-ptr attr-list) → Attr uptr
  register_binding(
      "mlir::ArrayAttr::get",
      [](uint64_t ctx_ptr, ptr attr_list) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(
                           ctx_ptr, "mlir::ArrayAttr::get"));
        llvm::SmallVector<mlir::Attribute> attrs;
        for (ptr p = attr_list; p != Snil; p = Scdr(p)) {
          uint64_t uv = Sunsigned64_value(Scar(p));
          attrs.push_back(mlir::Attribute::getFromOpaquePointer(
              reinterpret_cast<const void*>(uv)));
        }
        return reinterpret_cast<uint64_t>(
            mlir::ArrayAttr::get(ctx, attrs).getAsOpaquePointer());
      });

  // mlir::ArrayAttr::getElement — (attr-ptr idx) → Attr uptr
  register_binding("mlir::ArrayAttr::getElement",
                   [](uint64_t attr_ptr, uint64_t idx) -> uint64_t {
                     auto attr = mlir::Attribute::getFromOpaquePointer(
                         reinterpret_cast<const void*>(attr_ptr));
                     auto arr = mlir::cast<mlir::ArrayAttr>(attr);
                     if (idx >= arr.size()) {
                       return 0;
                     }
                     return reinterpret_cast<uint64_t>(
                         arr[static_cast<unsigned>(idx)].getAsOpaquePointer());
                   });

  // FlatSymbolRefAttr: a reference to a symbol by name, printed @name.
  register_binding(
      "mlir::FlatSymbolRefAttr::get",
      [](uint64_t ctx_ptr, const char* name) -> llvm::Expected<uint64_t> {
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            mlir::FlatSymbolRefAttr::get(ctx, name).getAsOpaquePointer());
      });
  register_binding("mlir::isa<FlatSymbolRefAttr>", [](uint64_t p) -> int {
    return (p && mlir::isa<mlir::FlatSymbolRefAttr>(
                     mlir::Attribute::getFromOpaquePointer(
                         reinterpret_cast<const void*>(p))))
               ? 1
               : 0;
  });
  register_binding("mlir::FlatSymbolRefAttr::getValue",
                   [](uint64_t attr_ptr) -> llvm::Expected<const char*> {
                     auto attr =
                         mlir::dyn_cast_if_present<mlir::FlatSymbolRefAttr>(
                             mlir::Attribute::getFromOpaquePointer(
                                 reinterpret_cast<const void*>(attr_ptr)));
                     if (!attr) {
                       return fail("mlir::FlatSymbolRefAttr::getValue",
                                   llvm::Twine("not a FlatSymbolRefAttr"));
                     }
                     return attr.getValue().data();
                   });

  register_binding("mlir::isa<ArrayAttr>", [](uint64_t p) -> int {
    return (p &&
            mlir::isa<mlir::ArrayAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p))))
               ? 1
               : 0;
  });

  register_binding("mlir::ArrayAttr::size",
                   [](uint64_t attr_ptr) -> llvm::Expected<int64_t> {
                     auto arr = mlir::dyn_cast_if_present<mlir::ArrayAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<const void*>(attr_ptr)));
                     if (!arr) {
                       return fail("mlir::ArrayAttr::size",
                                   llvm::Twine("not an ArrayAttr"));
                     }
                     return static_cast<int64_t>(arr.size());
                   });
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/BuiltinAttributes.h — attribute construction and inspection.

#include "BuiltinAttributes.h"
#include "../Support/ArrayRef.h"
#include "../Support/Logging.h"
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

  //===--------------------------------------------------------------------===//
  // Attr construction
  //===--------------------------------------------------------------------===//

  Sregister_symbol(
      "mlir::IntegerAttr::get<i64>",
      (void*)+[](uint64_t ctx_ptr, ptr value) -> uint64_t {
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        return reinterpret_cast<uint64_t>(
            mlir::IntegerAttr::get(mlir::IntegerType::get(ctx, 64),
                                   Sinteger64_value(value))
                .getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::IntegerAttr::get<index>",
      (void*)+[](uint64_t ctx_ptr, ptr value) -> uint64_t {
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        return reinterpret_cast<uint64_t>(
            mlir::IntegerAttr::get(mlir::IndexType::get(ctx),
                                   Sinteger64_value(value))
                .getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::FloatAttr::get<f32>",
      (void*)+[](uint64_t ctx_ptr, ptr value) -> uint64_t {
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        return reinterpret_cast<uint64_t>(
            mlir::FloatAttr::get(mlir::Float32Type::get(ctx),
                                 static_cast<float>(Sflonum_value(value)))
                .getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::DenseI32ArrayAttr::get",
      (void*)+[](uint64_t ctx_ptr, ptr value) -> uint64_t {
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
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
          // Attempt CArrayRef<int32_t> path. After ruling out vector and list,
          // value must be a uptr (raw C pointer as Scheme integer).
          // RISK: UB if caller passes an arbitrary integer — contract requires
          // list, vector, or CArrayRef<int32_t>.
          auto* obj = reinterpret_cast<crest::CrestObject*>(
              static_cast<uintptr_t>(Sunsigned_value(value)));
          if (obj->isa<CArrayRef<int32_t>>()) {
            auto* ref =
                static_cast<CArrayRef<int32_t>*>(static_cast<void*>(obj));
            for (size_t i = 0; i < ref->size; ++i) {
              vec.push_back(ref->data[i]);
            }
          } else {
            scheme_error(
                "mlir::DenseI32ArrayAttr::get",
                "value must be a Scheme list, vector, or CArrayRef<int32_t>;"
                " got a CrestObject with a different type tag");
          }
        }
        return reinterpret_cast<uint64_t>(
            mlir::DenseI32ArrayAttr::get(ctx, vec).getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::DenseI64ArrayAttr::get",
      (void*)+[](uint64_t ctx_ptr, ptr value) -> uint64_t {
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
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
          // Attempt CArrayRef<int64_t> — same RISK as i32 above.
          auto* obj = reinterpret_cast<crest::CrestObject*>(
              static_cast<uintptr_t>(Sunsigned_value(value)));
          if (obj->isa<CArrayRef<int64_t>>()) {
            auto* ref =
                static_cast<CArrayRef<int64_t>*>(static_cast<void*>(obj));
            for (size_t i = 0; i < ref->size; ++i) {
              vec.push_back(ref->data[i]);
            }
          } else {
            scheme_error(
                "mlir::DenseI64ArrayAttr::get",
                "value must be a Scheme list, vector, or CArrayRef<int64_t>;"
                " got a CrestObject with a different type tag");
          }
        }
        return reinterpret_cast<uint64_t>(
            mlir::DenseI64ArrayAttr::get(ctx, vec).getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::parseAttribute",
      (void*)+[](uint64_t ctx_ptr, const char* spec) -> uint64_t {
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        mlir::Attribute attr = mlir::parseAttribute(spec, ctx);
        if (!attr) {
          scheme_error("mlir::parseAttribute",
                       "failed to parse attribute: ", spec);
          return 0;
        }
        return reinterpret_cast<uint64_t>(attr.getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::DenseResourceElementsAttr::get",
      (void*)+[](uint64_t /*ctx_ptr*/, ptr value) -> uint64_t {
        auto result_type_ptr = Sunsigned64_value(Scar(value));
        // Inline schemeStringToStd for the key string
        ptr skey = Scar(Scdr(value));
        iptr klen = Sstring_length(skey);
        std::string key_str(static_cast<size_t>(klen), '\0');
        for (iptr i = 0; i < klen; ++i) {
          key_str[i] = static_cast<char>(Sstring_ref(skey, i));
        }
        int64_t data_addr = Sinteger64_value(Scar(Scdr(Scdr(value))));
        int64_t data_size = Sinteger64_value(Scar(Scdr(Scdr(Scdr(value)))));
        auto baseType = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(result_type_ptr));
        auto resultType = llvm::dyn_cast<mlir::RankedTensorType>(baseType);
        if (!resultType) {
          scheme_error("mlir::DenseResourceElementsAttr::get",
                       "result-type is not a RankedTensorType");
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

  Sregister_symbol(
      "mlir::UnitAttr::get", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::UnitAttr::get(reinterpret_cast<mlir::MLIRContext*>(ctx_ptr))
                .getAsOpaquePointer());
      });

  //===--------------------------------------------------------------------===//
  // Attribute type predicates
  //===--------------------------------------------------------------------===//

  Sregister_symbol(
      "mlir::isa<IntegerAttr>", (void*)+[](uint64_t p) -> int {
        return (p && mlir::isa<mlir::IntegerAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<const void*>(p))))
                   ? 1
                   : 0;
      });

  Sregister_symbol(
      "mlir::isa<FloatAttr>", (void*)+[](uint64_t p) -> int {
        return (p && mlir::isa<mlir::FloatAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<const void*>(p))))
                   ? 1
                   : 0;
      });

  Sregister_symbol(
      "mlir::isa<StringAttr>", (void*)+[](uint64_t p) -> int {
        return (p && mlir::isa<mlir::StringAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<const void*>(p))))
                   ? 1
                   : 0;
      });

  Sregister_symbol(
      "mlir::isa<DenseI32ArrayAttr>", (void*)+[](uint64_t p) -> int {
        return (p && mlir::isa<mlir::DenseI32ArrayAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<const void*>(p))))
                   ? 1
                   : 0;
      });

  Sregister_symbol(
      "mlir::isa<DenseElementsAttr>", (void*)+[](uint64_t p) -> int {
        return (p && mlir::isa<mlir::DenseElementsAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<const void*>(p))))
                   ? 1
                   : 0;
      });

  Sregister_symbol(
      "mlir::DenseElementsAttr::isSplat", (void*)+[](uint64_t p) -> int {
        if (!p) {
          return 0;
        }
        auto dense = mlir::dyn_cast<mlir::DenseElementsAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        return (dense && dense.isSplat()) ? 1 : 0;
      });

  // mlir::isa<FloatAttr>.f32 is the same check as mlir::isa<FloatAttr>.
  Sregister_symbol(
      "mlir::isa<FloatAttr>.f32", (void*)+[](uint64_t p) -> int {
        return (p && mlir::isa<mlir::FloatAttr>(
                         mlir::Attribute::getFromOpaquePointer(
                             reinterpret_cast<const void*>(p))))
                   ? 1
                   : 0;
      });

  //===--------------------------------------------------------------------===//
  // Scalar extraction
  //===--------------------------------------------------------------------===//

  Sregister_symbol(
      "mlir::IntegerAttr::getValue", (void*)+[](uint64_t p) -> ptr {
        if (!p) {
          scheme_error("mlir::IntegerAttr::getValue", "null attribute pointer");
        }
        auto iattr = mlir::dyn_cast<mlir::IntegerAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!iattr) {
          scheme_error("mlir::IntegerAttr::getValue",
                       "attribute is not an IntegerAttr");
        }
        return Sinteger64(iattr.getValue().getSExtValue());
      });

  Sregister_symbol(
      "mlir::FloatAttr::getValueAsDouble", (void*)+[](uint64_t p) -> ptr {
        if (!p) {
          scheme_error("mlir::FloatAttr::getValueAsDouble",
                       "null attribute pointer");
        }
        auto fattr = mlir::dyn_cast<mlir::FloatAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!fattr) {
          scheme_error("mlir::FloatAttr::getValueAsDouble",
                       "attribute is not a FloatAttr");
        }
        return Sflonum(fattr.getValueAsDouble());
      });

  // getValueAsDouble.f32 is identical to getValueAsDouble.
  Sregister_symbol(
      "mlir::FloatAttr::getValueAsDouble.f32", (void*)+[](uint64_t p) -> ptr {
        if (!p) {
          scheme_error("mlir::FloatAttr::getValueAsDouble.f32",
                       "null attribute pointer");
        }
        auto fattr = mlir::dyn_cast<mlir::FloatAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!fattr) {
          scheme_error("mlir::FloatAttr::getValueAsDouble.f32",
                       "attribute is not a FloatAttr");
        }
        return Sflonum(fattr.getValueAsDouble());
      });

  //===--------------------------------------------------------------------===//
  // Array ref / vector conversion
  //===--------------------------------------------------------------------===//

  Sregister_symbol(
      "mlir::DenseI64ArrayAttr::intoArrayRef",
      (void*)+[](uint64_t p) -> uint64_t {
        if (!p) {
          scheme_error("mlir::DenseI64ArrayAttr::intoArrayRef",
                       "null attribute pointer");
        }
        auto arr = mlir::dyn_cast<mlir::DenseI64ArrayAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!arr) {
          scheme_error("mlir::DenseI64ArrayAttr::intoArrayRef",
                       "attribute is not a DenseI64ArrayAttr");
        }
        return reinterpret_cast<uint64_t>(
            new CArrayRef<int64_t>(arr.asArrayRef().data(), arr.size()));
      });

  Sregister_symbol(
      "mlir::DenseI32ArrayAttr::intoArrayRef",
      (void*)+[](uint64_t p) -> uint64_t {
        if (!p) {
          scheme_error("mlir::DenseI32ArrayAttr::intoArrayRef",
                       "null attribute pointer");
        }
        auto arr = mlir::dyn_cast<mlir::DenseI32ArrayAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!arr) {
          scheme_error("mlir::DenseI32ArrayAttr::intoArrayRef",
                       "attribute is not a DenseI32ArrayAttr");
        }
        return reinterpret_cast<uint64_t>(
            new CArrayRef<int32_t>(arr.asArrayRef().data(), arr.size()));
      });

  Sregister_symbol(
      "mlir::DenseElementsAttr::getSplatValue<APFloat>",
      (void*)+[](uint64_t p) -> ptr {
        if (!p) {
          scheme_error("mlir::DenseElementsAttr::getSplatValue<APFloat>",
                       "null pointer");
        }
        auto d = mlir::dyn_cast<mlir::DenseFPElementsAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!d) {
          scheme_error("mlir::DenseElementsAttr::getSplatValue<APFloat>",
                       "not DenseFPElementsAttr");
        }
        if (!d.isSplat()) {
          scheme_error("mlir::DenseElementsAttr::getSplatValue<APFloat>",
                       "not a splat");
        }
        return Sflonum((*d.begin()).convertToDouble());
      });

  Sregister_symbol(
      "mlir::DenseElementsAttr::getSplatValue<APInt>",
      (void*)+[](uint64_t p) -> ptr {
        if (!p) {
          scheme_error("mlir::DenseElementsAttr::getSplatValue<APInt>",
                       "null pointer");
        }
        auto d = mlir::dyn_cast<mlir::DenseIntElementsAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!d) {
          scheme_error("mlir::DenseElementsAttr::getSplatValue<APInt>",
                       "not DenseIntElementsAttr");
        }
        if (!d.isSplat()) {
          scheme_error("mlir::DenseElementsAttr::getSplatValue<APInt>",
                       "not a splat");
        }
        return Sinteger64((*d.begin()).getSExtValue());
      });

  Sregister_symbol(
      "mlir::DenseI32ArrayAttr::toVector", (void*)+[](uint64_t p) -> ptr {
        if (!p) {
          scheme_error("mlir::DenseI32ArrayAttr::toVector",
                       "null attribute pointer");
        }
        auto arr = mlir::dyn_cast<mlir::DenseI32ArrayAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!arr) {
          scheme_error("mlir::DenseI32ArrayAttr::toVector",
                       "attribute is not a DenseI32ArrayAttr");
        }
        auto vals = arr.asArrayRef();
        ptr v = Smake_vector(static_cast<iptr>(vals.size()), Sfixnum(0));
        for (iptr i = 0; i < static_cast<iptr>(vals.size()); ++i) {
          Svector_set(v, i, Sfixnum(vals[i]));
        }
        return v;
      });

  Sregister_symbol(
      "mlir::DenseI64ArrayAttr::toVector", (void*)+[](uint64_t p) -> ptr {
        if (!p) {
          scheme_error("mlir::DenseI64ArrayAttr::toVector",
                       "null attribute pointer");
        }
        auto arr = mlir::dyn_cast<mlir::DenseI64ArrayAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(p)));
        if (!arr) {
          scheme_error("mlir::DenseI64ArrayAttr::toVector",
                       "attribute is not a DenseI64ArrayAttr");
        }
        auto vals = arr.asArrayRef();
        ptr v = Smake_vector(static_cast<iptr>(vals.size()), Sfixnum(0));
        for (iptr i = 0; i < static_cast<iptr>(vals.size()); ++i) {
          Svector_set(v, i, Sinteger(vals[i]));
        }
        return v;
      });
}

} // namespace crest

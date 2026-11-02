/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Toy Ch7 StructType — implemented on top of mlir::TupleType.
// TupleType is already registered in MLIR's builtin dialect, so it works
// out of the box without custom TypeStorage registration.

#include "ToyStructType.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/Types.h"

// We represent a StructType as a TupleType tagged with a marker attribute
// so we can distinguish it from plain TupleTypes. The tag is encoded by
// wrapping in a TupleType whose dialect is queried via isa<TupleType>.
// Since both StructType and TupleType have the same element-type semantics,
// this is a clean substitution.

namespace {
// TupleType-based StructType: just a TupleType — distinguishable from other
// types by being inside a TupleType wrapper. We use a simple convention:
// StructType(T1, T2) = TupleType<T1, T2>.
// toy::StructType? checks isa<mlir::TupleType>.
} // namespace

void registerToyStructTypeBindings() {
  // toy::StructType::get — create a TupleType from Scheme list of Type uptrss.
  Sregister_symbol(
      "toy::StructType::get", (void*)+[](ptr elem_list) -> uint64_t {
        llvm::SmallVector<mlir::Type> types;
        for (ptr p = elem_list; p != Snil; p = Scdr(p)) {
          uint64_t uv = Sunsigned64_value(Scar(p));
          types.push_back(mlir::Type::getFromOpaquePointer(
              reinterpret_cast<const void*>(uv)));
        }
        if (types.empty()) {
          return 0;
        }
        auto* ctx = types.front().getContext();
        auto tt = mlir::TupleType::get(ctx, types);
        return reinterpret_cast<uint64_t>(tt.getAsOpaquePointer());
      });

  // toy::StructType::getElementTypes — returns Scheme list of Type uptrss.
  Sregister_symbol(
      "toy::StructType::getElementTypes", (void*)+[](uint64_t type_ptr) -> ptr {
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto tt = mlir::cast<mlir::TupleType>(type);
        auto elems = tt.getTypes();
        ptr list = Snil;
        for (size_t i = elems.size(); i-- > 0;) {
          list = Scons(Sunsigned64(reinterpret_cast<uint64_t>(
                           elems[i].getAsOpaquePointer())),
                       list);
        }
        return list;
      });

  // toy::StructType::getNumElementTypes — (type-ptr) → fixnum
  Sregister_symbol(
      "toy::StructType::getNumElementTypes",
      (void*)+[](uint64_t type_ptr) -> uint64_t {
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto tt = mlir::cast<mlir::TupleType>(type);
        return static_cast<uint64_t>(tt.size());
      });

  // toy::StructType? — 1 if TupleType (our StructType representation), 0
  // otherwise
  Sregister_symbol(
      "toy::StructType?", (void*)+[](uint64_t type_ptr) -> int {
        if (!type_ptr) {
          return 0;
        }
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        return mlir::isa<mlir::TupleType>(type) ? 1 : 0;
      });

  // toy::StructType::getElementType — (type-ptr index) → Type uptr
  Sregister_symbol(
      "toy::StructType::getElementType",
      (void*)+[](uint64_t type_ptr, uint64_t idx) -> uint64_t {
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto tt = mlir::cast<mlir::TupleType>(type);
        if (idx >= tt.size()) {
          return 0;
        }
        return reinterpret_cast<uint64_t>(
            tt.getType(static_cast<unsigned>(idx)).getAsOpaquePointer());
      });
}

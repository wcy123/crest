/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors lib/Bindings/Support/ArrayRef.h (CREST-specific).

#include "ArrayRef.h"
#include "Result.h"
#include "SchemeWrapper.h"
#include "mlir/IR/TypeRange.h"
#include <cstring>

namespace crest {

void registerArrayRefBindings() {
  // crest::TypeRange::toList (uptr base, uptr size) -> list of Type
  //
  // A TypeRange that C++ passed by value, as its two words: a TypeRange is not
  // an array, its first word is a tagged union, so the elements are read here.
  Sregister_symbol(
      "crest::TypeRange::toList",
      (void*)+[](uint64_t base, uint64_t size) -> ptr {
        static_assert(sizeof(mlir::TypeRange) == 2 * sizeof(uint64_t),
                      "a TypeRange is two words");
        uint64_t words[2] = {base, size};
        mlir::TypeRange range;
        std::memcpy(&range, words, sizeof(words));
        llvm::SmallVector<mlir::Type> types(range.begin(), range.end());
        ptr list = Snil;
        for (auto it = types.rbegin(); it != types.rend(); ++it) {
          list = Scons(
              Sunsigned64(reinterpret_cast<uint64_t>(it->getAsOpaquePointer())),
              list);
        }
        return list;
      });

  // CrestObject::isa<CArrayRef<T>> — type predicates.
  // Non-capturing lambdas converted to plain function pointers via unary +.
  // The isa logic (deletor address comparison) stays in C++ where it belongs.
  Sregister_symbol(
      "crest::CArrayRef<uptr>?", (void*)+[](uint64_t p) -> ptr {
        return Sinteger64(reinterpret_cast<crest::CrestObject*>(p)
                                  ->isa<CArrayRef<uintptr_t>>()
                              ? 1
                              : 0);
      });
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors lib/Bindings/Support/ArrayRef.h (CREST-specific).

#include "ArrayRef.h"
#include "SchemeWrapper.h"

extern "C" {

// Allocate a CArrayRef<uintptr_t> on the C heap (generic uptr arrays).
static uint64_t mlir_support_array_ref_make(uint64_t data_ptr, uint64_t size) {
  auto* ref = new CArrayRef<uintptr_t>(
      reinterpret_cast<const uintptr_t*>(data_ptr), size);
  return reinterpret_cast<uint64_t>(ref);
}

} // extern "C"

namespace crest {

void registerArrayRefBindings() {
  Sregister_symbol("mlir_support_array_ref_make",
                   (void*)::mlir_support_array_ref_make);

  // CrestObject::isa<CArrayRef<T>> — type predicates.
  // Non-capturing lambdas converted to plain function pointers via unary +.
  // The isa logic (deletor address comparison) stays in C++ where it belongs.
  Sregister_symbol(
      "CArrayRef<i32>::isa", (void*)+[](uint64_t p) -> int {
        return reinterpret_cast<crest::CrestObject*>(p)
                       ->isa<CArrayRef<int32_t>>()
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "CArrayRef<i64>::isa", (void*)+[](uint64_t p) -> int {
        return reinterpret_cast<crest::CrestObject*>(p)
                       ->isa<CArrayRef<int64_t>>()
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "CArrayRef<uptr>::isa", (void*)+[](uint64_t p) -> int {
        return reinterpret_cast<crest::CrestObject*>(p)
                       ->isa<CArrayRef<uintptr_t>>()
                   ? 1
                   : 0;
      });
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors lib/Bindings/Support/ArrayRef.h (CREST-specific).

// C++ lifecycle bindings for (mlir support array-ref).
//
// The struct layout (matching llvm::ArrayRef<T> ABI):
//   offset 0: data uptr  — pointer to first element
//   offset 8: size uptr  — number of elements
//
// array-ref-size and array-ref-at are implemented in pure Scheme using
// foreign-ref (zero FFI overhead, compiles to raw load instructions).
// Only make/destroy require C++ since they manage heap memory.

#include "ArrayRef.h"
#include "SchemeWrapper.h"

extern "C" {

// Allocate a CArrayRef on the C heap and return its address as uptr.
static uint64_t mlir_support_array_ref_make(uint64_t data_ptr, uint64_t size) {
  auto* ref = new CArrayRef{data_ptr, size};
  return reinterpret_cast<uint64_t>(ref);
}

// Free a CArrayRef previously created by mlir_support_array_ref_make.
static void mlir_support_array_ref_destroy(uint64_t ref_ptr) {
  delete reinterpret_cast<CArrayRef*>(ref_ptr);
}

} // extern "C"

namespace crest {

void registerArrayRefBindings() {
  // New canonical names
  Sregister_symbol("mlir_support_array_ref_make",
                   (void*)::mlir_support_array_ref_make);
  Sregister_symbol("mlir_support_array_ref_destroy",
                   (void*)::mlir_support_array_ref_destroy);
  // Backward-compat aliases
  Sregister_symbol("mlir_array_ref_make", (void*)::mlir_support_array_ref_make);
  Sregister_symbol("mlir_array_ref_destroy",
                   (void*)::mlir_support_array_ref_destroy);
}

} // namespace crest

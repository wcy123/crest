/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors lib/Bindings/Support/ArrayRef.h (CREST-specific).

#include "ArrayRef.h"
#include "SchemeWrapper.h"

extern "C" {

// Allocate a CArrayRef on the C heap and return its address as uptr.
// The deletor (from AsCrest<CArrayRef>) is set automatically by the
// constructor. Layout: { deletor@0, data@8, size@16 }
static uint64_t mlir_support_array_ref_make(uint64_t data_ptr, uint64_t size) {
  auto* ref = new CArrayRef(reinterpret_cast<const void*>(data_ptr), size);
  return reinterpret_cast<uint64_t>(ref);
}

} // extern "C"

namespace crest {

void registerArrayRefBindings() {
  Sregister_symbol("mlir_support_array_ref_make",
                   (void*)::mlir_support_array_ref_make);
}

} // namespace crest

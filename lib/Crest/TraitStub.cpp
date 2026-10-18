/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Stub for DynamicOpTrait / addTrait — LLVM version is too old.
// Registers crest::add-op-trait! as a function that always errors,
// so Scheme code gets a clear diagnostic at runtime instead of a crash.

#include "../Bindings/Support/SchemeWrapper.h"

namespace crest {

void registerCrestTraitBindings() {
  Sregister_symbol(
      "crest::add-op-trait!",
      (void*)+[](uint64_t, const char* trait_name) -> void {
        scheme_error("crest::add-op-trait!",
                     "DynamicOpDefinition::addTrait() requires LLVM 23+; "
                     "requested trait: ",
                     trait_name);
      });
}

} // namespace crest

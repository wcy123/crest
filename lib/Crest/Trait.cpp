/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// CrestOp trait registration — requires LLVM 23+ (DynamicOpTrait / addTrait).

#include "Trait.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "Op.h"
#include "mlir/IR/ExtensibleDialect.h"

namespace crest {

void registerCrestTraitBindings() {
  // crest::add-op-trait! (uptr dynamic-op-def) (string trait-name) → void
  // Attaches a compile-time C++ trait TypeID to a runtime DynamicOpDefinition.
  // trait-name must be a key in the CREST trait registry
  // (e.g. "commutative", "pure", "elementwise").
  Sregister_symbol(
      "crest::add-op-trait!",
      (void*)+[](uint64_t def_ptr, const char* trait_name) -> void {
        auto* def = reinterpret_cast<mlir::DynamicOpDefinition*>(def_ptr);
        auto it = g_trait_registry.find(trait_name);
        if (it == g_trait_registry.end()) {
          scheme_error("crest::add-op-trait!",
                       "unknown trait name: ", trait_name);
        }
        def->addTrait(it->second());
      });
}

} // namespace crest

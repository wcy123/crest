/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Bindings for crest::CrestObject — generic foreign object base.
// See lib/Bindings/Support/CrestObject.h.
//
// Note: CrestObject::deletor is NOT a C binding — it is just a foreign-ref
// at offset 0, implemented directly in Scheme as:
//   (define (CrestObject::deletor obj) (foreign-ref 'uptr obj 0))

#include "CrestObject.h"
#include "SchemeWrapper.h"

namespace crest {

void registerCrestObjectBindings() {
  // Call the deletor stored at offset 0 of a CrestObject.
  // Needed as a C trampoline because Scheme cannot call a raw function pointer.
  Sregister_symbol(
      "CrestObject::delete", (void*)+[](uint64_t obj_ptr) -> void {
        auto* obj = reinterpret_cast<crest::CrestObject*>(obj_ptr);
        obj->deletor(obj);
      });
}

} // namespace crest

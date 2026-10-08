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

extern "C" {

// Call the deletor stored at offset 0 of a CrestObject, freeing the object.
// Needed as a C binding because Scheme cannot call an arbitrary function
// pointer (uptr) without a C-side trampoline.
static void crest_crest_object_delete(uint64_t obj_ptr) {
  auto* obj = reinterpret_cast<crest::CrestObject*>(obj_ptr);
  obj->deletor(obj);
}

} // extern "C"

namespace crest {

void registerCrestObjectBindings() {
  Sregister_symbol("CrestObject::delete", (void*)::crest_crest_object_delete);
}

} // namespace crest

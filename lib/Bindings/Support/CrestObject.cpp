/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors lib/Bindings/Support/CrestObject.h (CREST-specific).

// Note: crest::CrestObject::deletor is NOT a C binding — it is just a
// foreign-ref at offset 0, implemented directly in Scheme as:
//   (define (crest::CrestObject::deletor obj) (foreign-ref 'uptr obj 0))

#include "CrestObject.h"
#include "Result.h"
#include "SchemeWrapper.h"

namespace crest {

void crestObjectError(const char* who, const char* what) {
  scheme_error(who, what);
}

void registerCrestObjectBindings() {
  // Call the deletor stored at offset 0 of a CrestObject.
  // Needed as a C trampoline because Scheme cannot call a raw function pointer.
  Sregister_symbol(
      "crest::CrestObject::delete", (void*)+[](uint64_t obj_ptr) -> void {
        auto* obj = reinterpret_cast<crest::CrestObject*>(obj_ptr);
        obj->deletor(obj);
      });

  // crest::error::set (string who) (string message) → void
  //
  // The guard of a callable (scheme/crest/callback.sls) calls it with the text
  // of an error that it caught: the error is kept here, first one wins, and the
  // next binding that returns answers it to Scheme as the error object
  // (Result.h). It cannot fail.
  Sregister_symbol(
      "crest::error::set",
      (void*)+[](const char* who, const char* message) -> void {
        setCallbackError(who, message);
      });

  // crest::error::pendingFlag () → uptr: the address of the flag that says an
  // error is waiting in the slot. A callable (scheme/crest/callback.sls) reads
  // it before it runs Scheme: while an error is pending it answers the zero
  // value and runs nothing, so C++ code that retries (a greedy rewrite that
  // sees an op modified again and again) comes to an end, and the first error
  // is the one that is reported.
  Sregister_symbol(
      "crest::error::pendingFlag", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(&callbackError().pending);
      });

  // crest::bindings::answersObject (string name) → int: 1 when `name` was
  // registered with register_binding, so Scheme must call it through
  // crest-foreign-procedure.
  Sregister_symbol(
      "crest::bindings::answersObject", (void*)+[](const char* name) -> int {
        return detail::valueBindings().count(name) ? 1 : 0;
      });
}

} // namespace crest

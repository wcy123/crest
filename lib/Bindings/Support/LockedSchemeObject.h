/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#ifndef CREST_BINDINGS_LOCKED_SCHEME_OBJECT_H
#define CREST_BINDINGS_LOCKED_SCHEME_OBJECT_H

#include "SchemeWrapper.h"

namespace crest {

/// RAII wrapper for Scheme object GC locking.
///
/// Locks a Scheme object on construction and unlocks on destruction,
/// preventing the garbage collector from moving or collecting it.
/// Use when storing Scheme callbacks in C++ objects that outlive a single FFI
/// call.
class LockedSchemeObject {
public:
  explicit LockedSchemeObject(ptr obj);
  ~LockedSchemeObject();

  LockedSchemeObject(const LockedSchemeObject&) = delete;
  LockedSchemeObject& operator=(const LockedSchemeObject&) = delete;

  LockedSchemeObject(LockedSchemeObject&& other) noexcept;
  LockedSchemeObject& operator=(LockedSchemeObject&& other) noexcept;

  ptr get() const { return obj_; }
  operator ptr() const { return obj_; }

private:
  ptr obj_;
};

} // namespace crest

#endif // CREST_BINDINGS_LOCKED_SCHEME_OBJECT_H

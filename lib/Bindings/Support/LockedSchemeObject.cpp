/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Internal Scheme object locking — CREST-specific, no MLIR header mirror.

#include "LockedSchemeObject.h"

namespace crest {

LockedSchemeObject::LockedSchemeObject(ptr obj) : obj_(obj) {
  if (obj_ && obj_ != Sfalse) {
    Slock_object(obj_);
  }
}

LockedSchemeObject::~LockedSchemeObject() {
  if (obj_ && obj_ != Sfalse) {
    Sunlock_object(obj_);
  }
}

LockedSchemeObject::LockedSchemeObject(LockedSchemeObject&& other) noexcept
    : obj_(other.obj_) {
  other.obj_ = nullptr;
}

LockedSchemeObject&
LockedSchemeObject::operator=(LockedSchemeObject&& other) noexcept {
  if (this != &other) {
    if (obj_ && obj_ != Sfalse) {
      Sunlock_object(obj_);
    }
    obj_ = other.obj_;
    other.obj_ = nullptr;
  }
  return *this;
}

} // namespace crest

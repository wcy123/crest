/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#ifndef CREST_BINDINGS_FOREIGN_CALLABLE_H
#define CREST_BINDINGS_FOREIGN_CALLABLE_H

#include "SchemeWrapper.h"
#include <cstdint>
#include <utility>

namespace crest {

template <typename Signature> class ForeignCallable;

/// Owner of a C function that Scheme made for one run, with `foreign-callable`.
///
/// The Scheme side calls `crest-callback-entry-point`
/// (scheme/crest/callback.sls), which locks the code object of the callable and
/// gives its address. A callable made once per library is never freed and its
/// address is kept as a plain function pointer. One made for a run (a closure
/// that the user passes to a pattern, a type converter, a walk) has this owner:
/// it takes over that lock and releases it when the thing that calls the
/// function dies, so the code object can be collected. Unlock on a Scheme
/// thread, with Chez running, as LockedSchemeObject did.
///
/// Make the owner first in a binding, before a return or a check that can
/// raise: an error that leaves through Scheme skips destructors.
template <typename R, typename... Args> class ForeignCallable<R(Args...)> {
public:
  ForeignCallable() = default;
  explicit ForeignCallable(uint64_t entry) : entry_(entry) {}
  ~ForeignCallable() { release(); }

  ForeignCallable(const ForeignCallable&) = delete;
  ForeignCallable& operator=(const ForeignCallable&) = delete;

  ForeignCallable(ForeignCallable&& other) noexcept : entry_(other.entry_) {
    other.entry_ = 0;
  }
  ForeignCallable& operator=(ForeignCallable&& other) noexcept {
    if (this != &other) {
      release();
      entry_ = other.entry_;
      other.entry_ = 0;
    }
    return *this;
  }

  explicit operator bool() const { return entry_ != 0; }

  R operator()(Args... args) const {
    // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
    return reinterpret_cast<R (*)(Args...)>(entry_)(args...);
  }

private:
  void release() {
    if (entry_ != 0) {
      // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
      Sunlock_object(Sforeign_callable_code_object(
          reinterpret_cast<void*>(static_cast<uintptr_t>(entry_))));
      entry_ = 0;
    }
  }

  uint64_t entry_ = 0;
};

} // namespace crest

#endif // CREST_BINDINGS_FOREIGN_CALLABLE_H

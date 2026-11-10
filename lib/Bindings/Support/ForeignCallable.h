/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#ifndef CREST_BINDINGS_FOREIGN_CALLABLE_H
#define CREST_BINDINGS_FOREIGN_CALLABLE_H

#include "LockedSchemeObject.h"
#include "SchemeWrapper.h"
#include <cstddef>
#include <cstdint>
#include <string>
#include <utility>

namespace crest {

namespace detail {

/// The name that a foreign-callable gives a C++ type in its prototype.
template <typename T> struct ForeignTypeName;
#define CREST_FOREIGN_TYPE_NAME(Type, Name)                                    \
  template <> struct ForeignTypeName<Type> {                                   \
    static constexpr const char* value = Name;                                 \
  };
CREST_FOREIGN_TYPE_NAME(uint64_t, "uptr")
CREST_FOREIGN_TYPE_NAME(int, "int")
CREST_FOREIGN_TYPE_NAME(unsigned, "unsigned-32")
CREST_FOREIGN_TYPE_NAME(uint8_t, "unsigned-8")
CREST_FOREIGN_TYPE_NAME(void, "void")
#undef CREST_FOREIGN_TYPE_NAME

/// A pointer crosses as the number that is its address.
template <typename T> struct ForeignTypeName<T*> {
  static constexpr const char* value = "uptr";
};

/// The prototype of a foreign-callable as Scheme writes it, "(uptr int) void".
template <typename R, typename... Args> std::string foreignSignature() {
  std::string signature = "(";
  const char* separator = "";
  ((signature += separator, signature += ForeignTypeName<Args>::value,
    separator = " "),
   ...);
  signature += ") ";
  signature += ForeignTypeName<R>::value;
  return signature;
}

/// The Scheme procedure that makes the callables of one prototype: (lambda
/// (procedure) ...) answers the entry point of a foreign-callable of the
/// procedure, with its code object locked. It is compiled the first time the
/// prototype is used and kept, locked, for the life of the process.
ptr foreignCallableMaker(const std::string& signature);

/// How many makers there are: one per prototype that was used.
size_t foreignCallableMakerCount();

} // namespace detail

template <typename Signature> class ForeignCallable;

/// Owner of a C function that Scheme made for one run, with `foreign-callable`.
///
/// A callable made once per library is made on the Scheme side by
/// `crest-callback-entry-point` (scheme/crest/callback.sls), is never freed,
/// and its address is kept as a plain function pointer. One made for a run (a
/// closure that the user passes to a pattern, a type converter, a walk) has
/// this owner. It is made from the Scheme procedure with `fromProcedure`, or it
/// takes over the lock of a callable that `crest-callback-entry-point` made; it
/// releases the lock when the thing that calls the function dies, so the code
/// object can be collected. The unlock must happen on a Scheme thread, with
/// Chez running.
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

  /// The callable of `procedure`, a Scheme procedure, with the prototype
  /// R(Args...) that the C++ type says. `procedure` is locked while the
  /// callable is made, and the callable holds it from then on. Not a procedure:
  /// a Scheme error. Make the owner first in a binding, before anything that
  /// can raise.
  static ForeignCallable fromProcedure(ptr procedure) {
    // Locked before anything that can call Scheme: the garbage collector moves
    // objects.
    LockedSchemeObject locked(procedure);
    if (!Sprocedurep(locked.get())) {
      scheme_error("crest::ForeignCallable::fromProcedure",
                   "the callback is not a procedure");
    }
    ptr maker =
        detail::foreignCallableMaker(detail::foreignSignature<R, Args...>());
    return ForeignCallable(Sunsigned64_value(scheme_call(maker, locked.get())));
  }

  /// The address of the C function, 0 when there is none.
  uint64_t entry() const { return entry_; }

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

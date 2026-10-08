/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#ifndef CREST_BINDINGS_SCHEME_WRAPPER_H
#define CREST_BINDINGS_SCHEME_WRAPPER_H
#include "CrestObject.h"
#include <array>
#include <sstream>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>

// Wrapper for Chez Scheme's scheme.h
//
// Chez Scheme's generated scheme.h does NOT have include guards,
// which causes redefinition errors if included multiple times.
// This wrapper provides the protection.

extern "C" {
#include "boot/ta6le/scheme.h"
}
// Define your Scheme object handle type once.
// This assumes Sstring_to_symbol returns the standard Scheme value type.
using SValue = decltype(Sstring_to_symbol("x"));

// Portable unreachable hint. Needed because Scall2 (which invokes Scheme's
// error procedure via longjmp) is not declared [[noreturn]], so the compiler
// cannot see that control never returns from scheme_error. Without this hint,
// [[noreturn]] on scheme_error would produce a warning/error. std::unreachable
// is C++23; this macro achieves the same on C++17 across all target platforms.
[[noreturn]] inline void crest_unreachable() {
#ifdef _MSC_VER
  __assume(false);
#else
  __builtin_unreachable();
#endif
}

template <typename... Ts>
[[noreturn]] inline void scheme_error(const char* who, const Ts&... args) {
  std::ostringstream stream;

  bool first = true;
  auto append = [&](const auto& v) {
    if (!first) {
      stream << ' ';
    }
    first = false;
    stream << v;
  };

  // Write all arguments space-separated
  (append(args), ...);

  // Note: use stream.str().c_str() to get a const char*
  Scall2(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring(stream.str().c_str()));
  crest_unreachable();
}
// crest_cast<T> — validated CrestObject downcast.
// Checks null and isa<T> before casting; calls scheme_error on failure.
template <typename T>
[[nodiscard]] inline T* crest_cast(uint64_t ptr, const char* who) {
  if (!ptr) {
    scheme_error(who, "null pointer");
  }
  if (!reinterpret_cast<crest::CrestObject*>(ptr)->isa<T>()) {
    scheme_error(who, "wrong CrestObject type");
  }
  return reinterpret_cast<T*>(ptr);
}

// crest_owned<T> — extract T& from a CrestOwned<T>* at ptr.
template <typename T>
[[nodiscard]] inline T& crest_owned(uint64_t ptr, const char* who) {
  return crest_cast<crest::CrestOwned<T>>(ptr, who)->inner;
}

// crest_ref<T> — extract T* from a CrestRef<T>* at ptr.
template <typename T>
[[nodiscard]] inline T* crest_ref(uint64_t ptr, const char* who) {
  return crest_cast<crest::CrestRef<T>>(ptr, who)->ptr;
}

// ---- convert_to_scheme: explicit return types via overloads ----

// booleans
inline SValue convert_to_scheme(bool b) { return b ? Strue : Sfalse; }

// characters (encoded as single-character Scheme string)
inline SValue convert_to_scheme(char c) {
  char buf[2] = {c, '\0'};
  return Sstring(buf);
}

// Handle signed/unsigned char explicitly (treat as small integers)
inline SValue convert_to_scheme(signed char v) {
  return Sfixnum(static_cast<long>(v));
}
inline SValue convert_to_scheme(unsigned char v) {
  return Sfixnum(static_cast<long>(v));
}

// C strings
inline SValue convert_to_scheme(const char* s) { return Sstring(s ? s : ""); }
inline SValue convert_to_scheme(char* s) { return Sstring(s ? s : ""); }

// std::string / string_view
inline SValue convert_to_scheme(const std::string& s) {
  return Sstring(s.c_str());
}
inline SValue convert_to_scheme(std::string_view sv) {
  // If your runtime supports length-aware creation, prefer that.
  // Otherwise, materialize to a std::string so Sstring can copy it.
  std::string tmp(sv);
  return Sstring(tmp.c_str());
}

// signed integers
inline SValue convert_to_scheme(short v) {
  return Sfixnum(static_cast<long>(v));
}
inline SValue convert_to_scheme(int v) { return Sfixnum(static_cast<long>(v)); }
inline SValue convert_to_scheme(long v) {
  return Sfixnum(static_cast<long>(v));
}
inline SValue convert_to_scheme(long long v) {
  return Sfixnum(static_cast<long>(v));
}

// unsigned integers
inline SValue convert_to_scheme(unsigned short v) {
  return Sfixnum(static_cast<long>(v));
}
inline SValue convert_to_scheme(unsigned int v) {
  return Sfixnum(static_cast<long>(v));
}
inline SValue convert_to_scheme(unsigned long v) {
  return Sfixnum(static_cast<long>(v));
}
inline SValue convert_to_scheme(unsigned long long v) {
  return Sfixnum(static_cast<long>(v));
}

// floating point
inline SValue convert_to_scheme(float v) {
  return Sflonum(static_cast<double>(v));
}
inline SValue convert_to_scheme(double v) { return Sflonum(v); }
inline SValue convert_to_scheme(long double v) {
  return Sflonum(static_cast<double>(v));
}

// Optional: delete the catch-all to force adding a new overload for unsupported
// types. template <typename T> SValue convert_to_scheme(const T&) = delete;

// ---- list builder (returns a Scheme list; explicit return type) ----
template <typename... Ts> inline SValue make_scheme_list(Ts&&... args) {
  std::array<SValue, sizeof...(Ts)> items = {
      convert_to_scheme(std::forward<Ts>(args))...};

  SValue list = Snil;
  for (auto it = items.rbegin(); it != items.rend(); ++it) {
    list = Scons(*it, list);
  }
  return list;
}

// SValue identity — lets make_scheme_list accept already-converted args.
inline SValue convert_to_scheme(SValue v) { return v; }

// ---- scheme_call: direct Scall<N> for N ≤ 3; apply fallback for N > 3 ----
//
// Use scheme_call(proc, a, b, ...) when proc is an already-resolved SValue
// (e.g. from LockedSchemeObject). Prefer over scheme_apply(proc, list) for
// N ≤ 3: Scall<N> avoids the apply symbol lookup and list allocation.

inline SValue scheme_call(SValue proc) { return Scall0(proc); }
inline SValue scheme_call(SValue proc, SValue a1) { return Scall1(proc, a1); }
inline SValue scheme_call(SValue proc, SValue a1, SValue a2) {
  return Scall2(proc, a1, a2);
}
inline SValue scheme_call(SValue proc, SValue a1, SValue a2, SValue a3) {
  return Scall3(proc, a1, a2, a3);
}
// N = 4 — no Scall4; use Scons directly (exact behaviour match with old
// hand-built lists; avoids going through make_scheme_list/convert_to_scheme).
inline SValue scheme_call(SValue proc, SValue a1, SValue a2, SValue a3,
                          SValue a4) {
  SValue apply = Stop_level_value(Sstring_to_symbol("apply"));
  return Scall2(apply, proc, Scons(a1, Scons(a2, Scons(a3, Scons(a4, Snil)))));
}

// ---- scheme_call by name: symbol lookup + Scall<N> ----
//
// For one-off calls to named top-level procedures. Avoid in hot-path
// callbacks — symbol lookup fires on every call.

inline SValue scheme_call(const char* fname) {
  return Scall0(Stop_level_value(Sstring_to_symbol(fname)));
}
template <typename T1>
inline SValue scheme_call(const char* fname, const T1& a1) {
  return Scall1(Stop_level_value(Sstring_to_symbol(fname)),
                convert_to_scheme(a1));
}
template <typename T1, typename T2>
inline SValue scheme_call(const char* fname, const T1& a1, const T2& a2) {
  return Scall2(Stop_level_value(Sstring_to_symbol(fname)),
                convert_to_scheme(a1), convert_to_scheme(a2));
}
template <typename T1, typename T2, typename T3>
inline SValue scheme_call(const char* fname, const T1& a1, const T2& a2,
                          const T3& a3) {
  return Scall3(Stop_level_value(Sstring_to_symbol(fname)),
                convert_to_scheme(a1), convert_to_scheme(a2),
                convert_to_scheme(a3));
}
// N = 4 by name
template <typename T1, typename T2, typename T3, typename T4>
inline SValue scheme_call(const char* fname, const T1& a1, const T2& a2,
                          const T3& a3, const T4& a4) {
  SValue apply = Stop_level_value(Sstring_to_symbol("apply"));
  SValue func = Stop_level_value(Sstring_to_symbol(fname));
  return Scall2(apply, func,
                Scons(convert_to_scheme(a1),
                      Scons(convert_to_scheme(a2),
                            Scons(convert_to_scheme(a3),
                                  Scons(convert_to_scheme(a4), Snil)))));
}

#endif // CREST_BINDINGS_SCHEME_WRAPPER_H

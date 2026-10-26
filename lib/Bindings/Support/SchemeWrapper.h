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
// scheme.h is generated into the Chez workarea. The directory is the
// machine type selected in cmake/deps.cmake (ta6nt on Windows, ta6le
// elsewhere).
#if defined(_WIN32)
#  include "boot/ta6nt/scheme.h"
#else
#  include "boot/ta6le/scheme.h"
#endif
}
// Define your Scheme object handle type once.
// This assumes Sstring_to_symbol returns the standard Scheme value type.

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
inline ptr convert_to_scheme(bool b) { return b ? Strue : Sfalse; }

// characters (encoded as single-character Scheme string)
inline ptr convert_to_scheme(char c) {
  char buf[2] = {c, '\0'};
  return Sstring(buf);
}

// Handle signed/unsigned char explicitly (treat as small integers)
inline ptr convert_to_scheme(signed char v) {
  return Sfixnum(static_cast<long>(v));
}
inline ptr convert_to_scheme(unsigned char v) {
  return Sfixnum(static_cast<long>(v));
}

// Raw C++ pointer types → Scheme uptr (unsigned tagged integer).
// Non-template overloads (const char*, void*) take precedence in overload
// resolution, so char* → Sstring and ptr → identity are unaffected.
// WARNING: MLIR Op wrappers (ModuleOp, FuncOp, …) are NOT pointers — they
// convert to bool via operator bool(), not to Operation*. Always extract
// the underlying Operation* explicitly: op.getOperation().
template <typename T> inline ptr convert_to_scheme(T* p) {
  return Sunsigned64(reinterpret_cast<uint64_t>(p));
}

// C strings
inline ptr convert_to_scheme(const char* s) { return Sstring(s ? s : ""); }
inline ptr convert_to_scheme(char* s) { return Sstring(s ? s : ""); }

// std::string / string_view
inline ptr convert_to_scheme(const std::string& s) {
  return Sstring(s.c_str());
}
inline ptr convert_to_scheme(std::string_view sv) {
  // If your runtime supports length-aware creation, prefer that.
  // Otherwise, materialize to a std::string so Sstring can copy it.
  std::string tmp(sv);
  return Sstring(tmp.c_str());
}

// signed integers
inline ptr convert_to_scheme(short v) { return Sfixnum(static_cast<long>(v)); }
inline ptr convert_to_scheme(int v) { return Sfixnum(static_cast<long>(v)); }
inline ptr convert_to_scheme(long v) { return Sfixnum(static_cast<long>(v)); }
inline ptr convert_to_scheme(long long v) {
  return Sfixnum(static_cast<long>(v));
}

// unsigned integers
inline ptr convert_to_scheme(unsigned short v) {
  return Sfixnum(static_cast<long>(v));
}
inline ptr convert_to_scheme(unsigned int v) {
  return Sfixnum(static_cast<long>(v));
}
inline ptr convert_to_scheme(unsigned long v) {
  return Sfixnum(static_cast<long>(v));
}
inline ptr convert_to_scheme(unsigned long long v) {
  return Sfixnum(static_cast<long>(v));
}

// floating point
inline ptr convert_to_scheme(float v) {
  return Sflonum(static_cast<double>(v));
}
inline ptr convert_to_scheme(double v) { return Sflonum(v); }
inline ptr convert_to_scheme(long double v) {
  return Sflonum(static_cast<double>(v));
}

// Optional: delete the catch-all to force adding a new overload for unsupported
// types. template <typename T> ptr convert_to_scheme(const T&) = delete;

// ---- list builder (returns a Scheme list; explicit return type) ----
template <typename... Ts> inline ptr make_scheme_list(Ts&&... args) {
  std::array<ptr, sizeof...(Ts)> items = {
      convert_to_scheme(std::forward<Ts>(args))...};

  ptr list = Snil;
  for (auto it = items.rbegin(); it != items.rend(); ++it) {
    list = Scons(*it, list);
  }
  return list;
}

// ptr identity — lets make_scheme_list accept already-converted args.
inline ptr convert_to_scheme(ptr v) { return v; }

// ---- scheme_call: direct Scall<N> for N ≤ 3; apply+Scons for N = 4 ----
//
// The first argument is either:
//   ptr proc   — an already-resolved Scheme procedure (e.g. from
//   LockedSchemeObject) const char*   — a top-level name (symbol lookup fires
//   on each call; avoid in hot paths)
//
// convert_to_scheme_func unifies the two so a single set of overloads handles
// both.

// Resolve a top-level Scheme name to its procedure value.
// Logs to stderr and aborts if the name is unbound — defined in
// SchemeWrapper.cpp.
ptr convert_to_scheme_func(const char* fname);
inline ptr convert_to_scheme_func(ptr f) { return f; }

template <typename F> inline ptr scheme_call(F f) {
  return Scall0(convert_to_scheme_func(f));
}
template <typename F, typename T1> inline ptr scheme_call(F f, const T1& a1) {
  return Scall1(convert_to_scheme_func(f), convert_to_scheme(a1));
}
template <typename F, typename T1, typename T2>
inline ptr scheme_call(F f, const T1& a1, const T2& a2) {
  return Scall2(convert_to_scheme_func(f), convert_to_scheme(a1),
                convert_to_scheme(a2));
}
template <typename F, typename T1, typename T2, typename T3>
inline ptr scheme_call(F f, const T1& a1, const T2& a2, const T3& a3) {
  return Scall3(convert_to_scheme_func(f), convert_to_scheme(a1),
                convert_to_scheme(a2), convert_to_scheme(a3));
}
// N = 4 — no Scall4; fall back to (apply f args) via Scons.
template <typename F, typename T1, typename T2, typename T3, typename T4>
inline ptr scheme_call(F f, const T1& a1, const T2& a2, const T3& a3,
                       const T4& a4) {
  ptr apply = Stop_level_value(Sstring_to_symbol("apply"));
  return Scall2(apply, convert_to_scheme_func(f),
                Scons(convert_to_scheme(a1),
                      Scons(convert_to_scheme(a2),
                            Scons(convert_to_scheme(a3),
                                  Scons(convert_to_scheme(a4), Snil)))));
}

// ---- convert_to_cpp: extract a C++ value from a Scheme ptr ----
//
// These are the symmetric counterparts of convert_to_scheme.
// Each overload selects the right Chez Scheme accessor for the target type.

template <typename T> T convert_to_cpp(ptr v) = delete;

template <> inline bool convert_to_cpp<bool>(ptr v) { return v != Sfalse; }
template <> inline int convert_to_cpp<int>(ptr v) {
  return static_cast<int>(Sfixnum_value(v));
}
template <> inline long convert_to_cpp<long>(ptr v) { return Sfixnum_value(v); }
template <> inline unsigned int convert_to_cpp<unsigned int>(ptr v) {
  return static_cast<unsigned int>(Sunsigned64_value(v));
}
template <> inline uint64_t convert_to_cpp<uint64_t>(ptr v) {
  return Sunsigned64_value(v);
}
template <> inline double convert_to_cpp<double>(ptr v) {
  return Sflonum_value(v);
}
template <> inline const char* convert_to_cpp<const char*>(ptr v) {
  return Sstring_value(v);
}
template <> inline std::string convert_to_cpp<std::string>(ptr v) {
  return std::string(Sstring_value(v));
}
// ptr identity -- a Scheme ptr is already a ptr.
template <> inline ptr convert_to_cpp<ptr>(ptr v) { return v; }

#endif // CREST_BINDINGS_SCHEME_WRAPPER_H

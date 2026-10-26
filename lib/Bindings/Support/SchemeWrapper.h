/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Wrapper for Chez Scheme's scheme.h
//
// Chez Scheme's generated scheme.h does NOT have include guards,
// which causes redefinition errors if included multiple times.
// This wrapper provides the protection.

#ifndef CREST_BINDINGS_SCHEME_WRAPPER_H
#define CREST_BINDINGS_SCHEME_WRAPPER_H
#include "CrestObject.h"
#include <array>
#include <sstream>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>

extern "C" {
#if defined(_WIN32)
#  include "boot/ta6nt/scheme.h"
#else
#  include "boot/ta6le/scheme.h"
#endif
}

// Portable unreachable hint.
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
  (append(args), ...);
  Scall2(Stop_level_value(Sstring_to_symbol("error")), Sstring(who),
         Sstring(stream.str().c_str()));
  crest_unreachable();
}

template <typename T>
[[nodiscard]] inline T* crest_cast(uint64_t ptr_val, const char* who) {
  if (!ptr_val) {
    scheme_error(who, "null pointer");
  }
  if (!reinterpret_cast<crest::CrestObject*>(ptr_val)->isa<T>()) {
    scheme_error(who, "wrong CrestObject type");
  }
  return reinterpret_cast<T*>(ptr_val);
}

template <typename T>
[[nodiscard]] inline T& crest_owned(uint64_t ptr_val, const char* who) {
  return crest_cast<crest::CrestOwned<T>>(ptr_val, who)->inner;
}

template <typename T>
[[nodiscard]] inline T* crest_ref(uint64_t ptr_val, const char* who) {
  return crest_cast<crest::CrestRef<T>>(ptr_val, who)->ptr;
}

// ---------------------------------------------------------------------------
// Conversion<From, To>
//
// Unified conversion template.  The primary template declares operator()
// without a definition — any unsupported combination is a link error.
// Explicit specialisations live in SchemeWrapper.cpp.
//
// convert_to_scheme(v)      wraps Conversion<From, ptr>
// convert_to_cpp<To>(v)     wraps Conversion<ptr, To>
// ---------------------------------------------------------------------------
template <typename From, typename To> struct Conversion {
  To operator()(const From& from); // undefined by design
};

template <typename From> inline ptr convert_to_scheme(const From& v) {
  return Conversion<From, ptr>{}(v);
}

template <typename To> inline To convert_to_cpp(ptr v) {
  return Conversion<ptr, To>{}(v);
}

// ---- make_scheme_list ----
template <typename... Ts> inline ptr make_scheme_list(Ts&&... args) {
  std::array<ptr, sizeof...(Ts)> items = {
      convert_to_scheme(std::forward<Ts>(args))...};
  ptr list = Snil;
  for (auto it = items.rbegin(); it != items.rend(); ++it) {
    list = Scons(*it, list);
  }
  return list;
}

// ---- scheme_call ----
//
// The first argument is either:
//   ptr          — an already-resolved Scheme procedure
//   const char*  — a top-level name (symbol lookup fires on each call)
ptr convert_to_scheme_func(const char* fname); // defined in SchemeWrapper.cpp
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
// N=4: fall back to (apply f args)
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

#endif // CREST_BINDINGS_SCHEME_WRAPPER_H

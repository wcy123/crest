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

// Partial specialisation for raw pointer types: any T* → uptr.
// Inline class body avoids multiple-definition errors across TUs.
template <typename T> struct Conversion<T*, ptr> {
  inline ptr operator()(T* const& p) const {
    return Sunsigned64(reinterpret_cast<uint64_t>(p));
  }
};

template <typename To> inline To convert_to_cpp(ptr v) {
  return Conversion<ptr, To>{}(v);
}

// ---- make_scheme_list ----
template <typename... Ts> inline ptr make_scheme_list(Ts&&... args) {
  std::array<ptr, sizeof...(Ts)> items = {
      Conversion<std::decay_t<Ts>, ptr>{}(std::forward<Ts>(args))...};
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
  return Scall1(convert_to_scheme_func(f), Conversion<T1, ptr>{}(a1));
}
template <typename F, typename T1, typename T2>
inline ptr scheme_call(F f, const T1& a1, const T2& a2) {
  return Scall2(convert_to_scheme_func(f), Conversion<T1, ptr>{}(a1),
                Conversion<T2, ptr>{}(a2));
}
template <typename F, typename T1, typename T2, typename T3>
inline ptr scheme_call(F f, const T1& a1, const T2& a2, const T3& a3) {
  return Scall3(convert_to_scheme_func(f), Conversion<T1, ptr>{}(a1),
                Conversion<T2, ptr>{}(a2), Conversion<T3, ptr>{}(a3));
}
// N=4: fall back to (apply f args)
template <typename F, typename T1, typename T2, typename T3, typename T4>
inline ptr scheme_call(F f, const T1& a1, const T2& a2, const T3& a3,
                       const T4& a4) {
  ptr apply = Stop_level_value(Sstring_to_symbol("apply"));
  return Scall2(apply, convert_to_scheme_func(f),
                Scons(Conversion<T1, ptr>{}(a1),
                      Scons(Conversion<T2, ptr>{}(a2),
                            Scons(Conversion<T3, ptr>{}(a3),
                                  Scons(Conversion<T4, ptr>{}(a4), Snil)))));
}

// ---------------------------------------------------------------------------
// Conversion<From,To> explicit specialisations (inline — all in header)
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Conversion<From, To> explicit specialisations
//
// C++ → Scheme (From = C++ type, To = ptr)
// ---------------------------------------------------------------------------

template <> inline ptr Conversion<bool, ptr>::operator()(const bool& v) {
  return v ? Strue : Sfalse;
}
template <> inline ptr Conversion<char, ptr>::operator()(const char& v) {
  char buf[2] = {v, '\0'};
  return Sstring(buf);
}
template <>
inline ptr Conversion<signed char, ptr>::operator()(const signed char& v) {
  return Sfixnum(static_cast<long>(v));
}
template <>
inline ptr Conversion<unsigned char, ptr>::operator()(const unsigned char& v) {
  return Sfixnum(static_cast<long>(v));
}
template <> inline ptr Conversion<short, ptr>::operator()(const short& v) {
  return Sfixnum(static_cast<long>(v));
}
template <> inline ptr Conversion<int, ptr>::operator()(const int& v) {
  return Sfixnum(static_cast<long>(v));
}
template <> inline ptr Conversion<long, ptr>::operator()(const long& v) {
  return Sfixnum(v);
}
template <>
inline ptr Conversion<long long, ptr>::operator()(const long long& v) {
  return Sfixnum(static_cast<long>(v));
}
template <>
inline ptr
Conversion<unsigned short, ptr>::operator()(const unsigned short& v) {
  return Sfixnum(static_cast<long>(v));
}
template <>
inline ptr Conversion<unsigned int, ptr>::operator()(const unsigned int& v) {
  return Sfixnum(static_cast<long>(v));
}
template <>
inline ptr Conversion<unsigned long, ptr>::operator()(const unsigned long& v) {
  return Sfixnum(static_cast<long>(v));
}
template <>
inline ptr
Conversion<unsigned long long, ptr>::operator()(const unsigned long long& v) {
  return Sunsigned64(v);
}
template <> inline ptr Conversion<float, ptr>::operator()(const float& v) {
  return Sflonum(static_cast<double>(v));
}
template <> inline ptr Conversion<double, ptr>::operator()(const double& v) {
  return Sflonum(v);
}
template <>
inline ptr Conversion<long double, ptr>::operator()(const long double& v) {
  return Sflonum(static_cast<double>(v));
}
template <> struct Conversion<const char*, ptr> {
  inline ptr operator()(const char* const& v) const {
    return Sstring(v ? v : "");
  }
};
template <> struct Conversion<char*, ptr> {
  inline ptr operator()(char* const& v) const { return Sstring(v ? v : ""); }
};
template <>
inline ptr Conversion<std::string, ptr>::operator()(const std::string& v) {
  return Sstring(v.c_str());
}
template <>
inline ptr
Conversion<std::string_view, ptr>::operator()(const std::string_view& v) {
  std::string tmp(v);
  return Sstring(tmp.c_str());
}
// ptr identity — full class spec takes precedence over Conversion<T*, ptr>
template <> struct Conversion<ptr, ptr> {
  inline ptr operator()(const ptr& v) const { return v; }
};

// ---------------------------------------------------------------------------
// Scheme → C++ (From = ptr, To = C++ type)
// ---------------------------------------------------------------------------

template <> inline bool Conversion<ptr, bool>::operator()(const ptr& v) {
  return v != Sfalse;
}
template <> inline int Conversion<ptr, int>::operator()(const ptr& v) {
  return static_cast<int>(Sfixnum_value(v));
}
template <> inline long Conversion<ptr, long>::operator()(const ptr& v) {
  return Sfixnum_value(v);
}
template <>
inline unsigned int Conversion<ptr, unsigned int>::operator()(const ptr& v) {
  return static_cast<unsigned int>(Sunsigned64_value(v));
}
template <>
inline uint64_t Conversion<ptr, uint64_t>::operator()(const ptr& v) {
  return Sunsigned64_value(v);
}
template <> inline double Conversion<ptr, double>::operator()(const ptr& v) {
  return Sflonum_value(v);
}
// Conversion<ptr, const char*>: omitted -- Chez Scheme strings use 32-bit
// chars internally; no stable char* can be returned.  Use std::string instead.

// Conversion<ptr, std::string>: extract via Sstring_length + Sstring_ref.
// Chez Scheme string_char is unsigned int; take the low byte for ASCII.
template <>
inline std::string Conversion<ptr, std::string>::operator()(const ptr& v) {
  iptr len = Sstring_length(v);
  std::string result;
  result.reserve(static_cast<std::size_t>(len));
  for (iptr i = 0; i < len; ++i) {
    result += static_cast<char>(Sstring_ref(v, i) & 0xFF);
  }
  return result;
}

#endif // CREST_BINDINGS_SCHEME_WRAPPER_H

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#ifndef CREST_BINDINGS_SCHEME_WRAPPER_H
#define CREST_BINDINGS_SCHEME_WRAPPER_H
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

template <typename... Ts>
inline void scheme_error(const char* who, const Ts&... args) {
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

// ---- scheme_apply with explicit return type ----

// Call a named top-level Scheme procedure: (apply func_name args...)
template <typename... Ts>
inline SValue scheme_apply(const char* func_name, Ts&&... args) {
  SValue apply = Stop_level_value(Sstring_to_symbol("apply"));
  SValue func = Stop_level_value(Sstring_to_symbol(func_name));
  SValue scheme_args = make_scheme_list(std::forward<Ts>(args)...);
  return Scall2(apply, func, scheme_args);
}

// Call an already-resolved Scheme procedure ptr: (apply proc args...)
// Use this when the callback is stored as a ptr (e.g. LockedSchemeObject).
inline SValue scheme_apply(SValue proc, SValue args_list) {
  SValue apply = Stop_level_value(Sstring_to_symbol("apply"));
  return Scall2(apply, proc, args_list);
}
#endif // CREST_BINDINGS_SCHEME_WRAPPER_H

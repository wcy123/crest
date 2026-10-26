/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#include "SchemeWrapper.h"

// ---------------------------------------------------------------------------
// Conversion<From, To> explicit specialisations
//
// C++ → Scheme (From = C++ type, To = ptr)
// ---------------------------------------------------------------------------

template <> ptr Conversion<bool, ptr>::operator()(const bool& v) {
  return v ? Strue : Sfalse;
}
template <> ptr Conversion<char, ptr>::operator()(const char& v) {
  char buf[2] = {v, '\0'};
  return Sstring(buf);
}
template <> ptr Conversion<signed char, ptr>::operator()(const signed char& v) {
  return Sfixnum(static_cast<long>(v));
}
template <>
ptr Conversion<unsigned char, ptr>::operator()(const unsigned char& v) {
  return Sfixnum(static_cast<long>(v));
}
template <> ptr Conversion<short, ptr>::operator()(const short& v) {
  return Sfixnum(static_cast<long>(v));
}
template <> ptr Conversion<int, ptr>::operator()(const int& v) {
  return Sfixnum(static_cast<long>(v));
}
template <> ptr Conversion<long, ptr>::operator()(const long& v) {
  return Sfixnum(v);
}
template <> ptr Conversion<long long, ptr>::operator()(const long long& v) {
  return Sfixnum(static_cast<long>(v));
}
template <>
ptr Conversion<unsigned short, ptr>::operator()(const unsigned short& v) {
  return Sfixnum(static_cast<long>(v));
}
template <>
ptr Conversion<unsigned int, ptr>::operator()(const unsigned int& v) {
  return Sfixnum(static_cast<long>(v));
}
template <>
ptr Conversion<unsigned long, ptr>::operator()(const unsigned long& v) {
  return Sfixnum(static_cast<long>(v));
}
template <>
ptr Conversion<unsigned long long, ptr>::operator()(
    const unsigned long long& v) {
  return Sunsigned64(v);
}
template <> ptr Conversion<float, ptr>::operator()(const float& v) {
  return Sflonum(static_cast<double>(v));
}
template <> ptr Conversion<double, ptr>::operator()(const double& v) {
  return Sflonum(v);
}
template <> ptr Conversion<long double, ptr>::operator()(const long double& v) {
  return Sflonum(static_cast<double>(v));
}
template <> ptr Conversion<const char*, ptr>::operator()(const char* const& v) {
  return Sstring(v ? v : "");
}
template <> ptr Conversion<char*, ptr>::operator()(char* const& v) {
  return Sstring(v ? v : "");
}
template <> ptr Conversion<std::string, ptr>::operator()(const std::string& v) {
  return Sstring(v.c_str());
}
template <>
ptr Conversion<std::string_view, ptr>::operator()(const std::string_view& v) {
  std::string tmp(v);
  return Sstring(tmp.c_str());
}
// ptr identity
template <> ptr Conversion<ptr, ptr>::operator()(const ptr& v) { return v; }

// ---------------------------------------------------------------------------
// Scheme → C++ (From = ptr, To = C++ type)
// ---------------------------------------------------------------------------

template <> bool Conversion<ptr, bool>::operator()(const ptr& v) {
  return v != Sfalse;
}
template <> int Conversion<ptr, int>::operator()(const ptr& v) {
  return static_cast<int>(Sfixnum_value(v));
}
template <> long Conversion<ptr, long>::operator()(const ptr& v) {
  return Sfixnum_value(v);
}
template <>
unsigned int Conversion<ptr, unsigned int>::operator()(const ptr& v) {
  return static_cast<unsigned int>(Sunsigned64_value(v));
}
template <> uint64_t Conversion<ptr, uint64_t>::operator()(const ptr& v) {
  return Sunsigned64_value(v);
}
template <> double Conversion<ptr, double>::operator()(const ptr& v) {
  return Sflonum_value(v);
}
template <> const char* Conversion<ptr, const char*>::operator()(const ptr& v) {
  return Sstring_value(v);
}
template <> std::string Conversion<ptr, std::string>::operator()(const ptr& v) {
  return std::string(Sstring_value(v));
}

// ---------------------------------------------------------------------------
// convert_to_scheme_func — resolve a Scheme top-level name to a procedure.
// ---------------------------------------------------------------------------

ptr convert_to_scheme_func(const char* fname) {
  ptr f = Stop_level_value(Sstring_to_symbol(fname));
  if (f == Sfalse) {
    fprintf(stderr, "error: scheme_call: unbound Scheme function '%s'\n",
            fname);
    std::abort();
  }
  return f;
}

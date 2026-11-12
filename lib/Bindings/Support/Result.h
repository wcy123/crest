/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// How errors cross between C++ and Scheme: as return values, in both
// directions. Nothing is raised across a C function (Chez leaks the frames of a
// C call that an error escapes,
// cmake/patches/chez-release-escaped-frames.patch).
//
// Scheme calls C++ (a binding): the binding answers a Scheme object, the value
// itself (Sunsigned64, scheme_bool, Svoid, a string, a list) or, on failure,
// scheme_error(who, why): the pair (who . why), who a symbol and why a string.
// crest-foreign-procedure ((mlir support foreign)) raises the pair in Scheme,
// after the C function has returned.
//
// C++ calls Scheme (a callable made by scheme/crest/callback.sls, or
// crest-call-guarded): Scheme wraps the procedure in a guard, so it never
// raises. It answers the value (a number, #t, #f, void) or, when the procedure
// raised an error, the pair (who . why). The C++ code that made the call checks
// the answer with isSchemeError, reports the error as an MLIR diagnostic, as
// the C++ hooks of MLIR do (emitSchemeError), and answers failure to MLIR.
//
// The callables of an interface slot (MLIR calls them with its own prototype)
// are not guarded: a Scheme procedure of a slot must not raise.

#ifndef CREST_BINDINGS_SUPPORT_RESULT_H
#define CREST_BINDINGS_SUPPORT_RESULT_H

#include "SchemeWrapper.h"
#include "llvm/ADT/Twine.h"
#include "mlir/IR/Diagnostics.h"
#include "mlir/IR/Location.h"
#include <cstring>
#include <string>

namespace crest {

// The failure of a binding: (who . why), who the name of the binding.
inline ptr scheme_error(const char* who, const llvm::Twine& why) {
  std::string text = why.str();
  return Scons(Sstring_to_symbol(who),
               Sstring_utf8(text.data(), static_cast<iptr>(text.size())));
}

// A boolean answer.
inline ptr scheme_bool(bool value) { return value ? Strue : Sfalse; }

// A string answer; a null const char* is #f.
inline ptr scheme_string(const char* text) {
  return text ? Sstring_utf8(text, static_cast<iptr>(std::strlen(text)))
              : Sfalse;
}
inline ptr scheme_string(const std::string& text) {
  return Sstring_utf8(text.data(), static_cast<iptr>(text.size()));
}

// ---- C++ reads the answer of a callable that Scheme made ----

// Whether the answer is the error (who . why). No value that a callable
// answers is a pair of a symbol and a string.
inline bool isSchemeError(ptr answer) {
  return Spairp(answer) && Ssymbolp(Scar(answer)) && Sstringp(Scdr(answer));
}

namespace detail {
inline std::string schemeText(ptr string) {
  std::string text;
  for (iptr i = 0; i < Sstring_length(string); ++i) {
    text.push_back(static_cast<char>(Sstring_ref(string, i)));
  }
  return text;
}
} // namespace detail

// The text of an error answer: "who: why", or "why" when who is empty.
inline std::string schemeErrorText(ptr answer) {
  std::string who = detail::schemeText(Ssymbol_to_string(Scar(answer)));
  std::string why = detail::schemeText(Scdr(answer));
  return who.empty() ? why : who + ": " + why;
}

// Report the error answer as a diagnostic at `loc`. The caller then answers
// failure to MLIR.
inline void emitSchemeError(mlir::Location loc, ptr answer) {
  mlir::emitError(loc) << schemeErrorText(answer);
}

// The first error that the callables run by one binding answered. A binding
// that calls a callable itself (walk, modifyOpInPlace, buildAffineLoopNest)
// keeps the error here, on its stack, stops, and answers it to Scheme, which
// raises it there. The text is copied: Scheme may move the pair.
class FirstSchemeError {
public:
  // Whether `answer` is an error; the first one is kept.
  bool record(ptr answer) {
    if (!isSchemeError(answer)) {
      return false;
    }
    if (!failed_) {
      failed_ = true;
      who_ = detail::schemeText(Ssymbol_to_string(Scar(answer)));
      why_ = detail::schemeText(Scdr(answer));
    }
    return true;
  }
  explicit operator bool() const { return failed_; }
  ptr answer() const { return scheme_error(who_.c_str(), why_); }

private:
  bool failed_ = false;
  std::string who_;
  std::string why_;
};

} // namespace crest

#endif // CREST_BINDINGS_SUPPORT_RESULT_H

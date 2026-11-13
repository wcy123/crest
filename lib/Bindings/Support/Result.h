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
// C++ calls Scheme through a callable that scheme/crest/callback.sls made: the
// callable has the C prototype that C++ or MLIR declares, result type included,
// and its guard reports an error of the procedure itself (mlir::emitError, or
// llvm::report_fatal_error for a void result), so no error reaches C++ and C++
// decodes nothing.

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

} // namespace crest

#endif // CREST_BINDINGS_SUPPORT_RESULT_H

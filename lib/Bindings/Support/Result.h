/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// How a binding answers Scheme.
//
// A binding is a plain C function that answers a Scheme object:
//   - on success the value itself (Sunsigned64, Strue, Svoid, a string, a
//   list);
//   - on failure scheme_error(who, why): the pair (who . why), who a symbol and
//     why a string.
// Scheme calls it through crest-foreign-procedure ((mlir support foreign)),
// which raises the pair as a Scheme error after the C function has returned.
// C++ never raises: no error crosses a C function (Chez leaks the frames of a C
// call that an error escapes, cmake/patches/chez-release-escaped-frames.patch).
//
// A callback that Scheme made (scheme/crest/callback.sls) never raises either:
// it catches the error, stores it in the slot below, and answers the zero
// value. crest-foreign-procedure raises the stored error when the binding that
// ran the callback returns.

#ifndef CREST_BINDINGS_SUPPORT_RESULT_H
#define CREST_BINDINGS_SUPPORT_RESULT_H

#include "SchemeWrapper.h"
#include "llvm/ADT/Twine.h"
#include "llvm/Support/ErrorHandling.h"
#include <cstring>
#include <string>

namespace crest {

// The failure of a binding: (who . why), who the name of the binding.
inline ptr scheme_error(const char* who, const llvm::Twine& why) {
  std::string text = why.str();
  return Scons(Sstring_to_symbol(who),
               Sstring_utf8(text.data(), static_cast<iptr>(text.size())));
}

// A string answer; a null const char* is #f.
inline ptr scheme_string(const char* text) {
  return text ? Sstring_utf8(text, static_cast<iptr>(std::strlen(text)))
              : Sfalse;
}
inline ptr scheme_string(const std::string& text) {
  return Sstring_utf8(text.data(), static_cast<iptr>(text.size()));
}

// ---- the error of a callback ----
//
// Scheme (the guard of a callable) puts the text of the error here through
// crest::error::set and answers the zero value to C++. The first error wins.
// crest-foreign-procedure asks for it with crest::error::take when the binding
// returns, and a callable asks crest::error::pending before it runs.

struct CallbackError {
  bool pending = false;
  std::string who;
  std::string message;
};

inline CallbackError& callbackError() {
  static thread_local CallbackError slot;
  return slot;
}

inline void setCallbackError(const std::string& who,
                             const std::string& message) {
  CallbackError& slot = callbackError();
  if (!slot.pending) {
    slot.pending = true;
    slot.who = who;
    slot.message = message;
  }
}

// The error in the slot as (who . why), and the slot is empty; #f when there is
// none.
inline ptr takeCallbackError() {
  CallbackError& slot = callbackError();
  if (!slot.pending) {
    return Sfalse;
  }
  ptr error = scheme_error(slot.who.c_str(), slot.message);
  slot = CallbackError();
  return error;
}

// Whether somebody will raise the error that a callback stored, when the
// binding that ran it returns. In a Scheme program somebody does. In crest-opt
// MLIR drives, and loads a Scheme dialect while it parses: nobody does, and
// failIfUnanswered stops the process. crest-opt says so once at startup, and
// the pass of --crest-pass says it is a Scheme program for the time it runs.
inline bool& unansweredErrorStops() {
  static bool stops = false;
  return stops;
}

// Call it where C++ has just run a Scheme callback: stop with the text when
// there is an error and nobody will raise it.
inline void failIfUnanswered() {
  CallbackError& slot = callbackError();
  if (slot.pending && unansweredErrorStops()) {
    std::string text =
        slot.who.empty() ? slot.message : slot.who + ": " + slot.message;
    slot = CallbackError();
    llvm::report_fatal_error(llvm::Twine(text), /*gen_crash_diag=*/false);
  }
}

} // namespace crest

#endif // CREST_BINDINGS_SUPPORT_RESULT_H

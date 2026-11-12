/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// How a binding answers Scheme (plans/04-errors-are-values.md).
//
// register_binding("name", [](args) -> R { ... }) replaces
// Sregister_symbol("name", (void*)+[](args) -> R { ... }). The lambda answers a
// C++ value, nothing, an llvm::Error, or an llvm::Expected<T>. The function
// that Scheme calls answers a Scheme OBJECT:
//   - a success is the value itself (an integer, #t/#f, a string, a list, the
//   void object);
//   - a failure is the error object (#!eof who . message), a pair whose first
//   element is the eof
//     object, which no list that a binding answers can start with.
// Scheme calls the symbol through crest-foreign-procedure ((mlir support
// foreign)), which raises the error object in Scheme, after the C++ call has
// returned: no error crosses a C function.
//
// A callback that Scheme made (scheme/crest/callback.sls) never raises either:
// it catches the error, stores it in the slot below, and answers the zero
// value. The function registered here checks the slot when the lambda returns,
// and answers the stored error instead of the result.

#ifndef CREST_BINDINGS_SUPPORT_RESULT_H
#define CREST_BINDINGS_SUPPORT_RESULT_H

#include "Error.h"
#include "SchemeWrapper.h"
#include <cstdint>
#include <cstring>
#include <optional>
#include <set>
#include <string>
#include <tuple>
#include <type_traits>
#include <utility>

namespace crest {

// The error object: (#!eof who . message), who and message as strings (UTF-8).
inline ptr errorObject(const std::string& who, const std::string& message) {
  ptr whoText = Sstring_utf8(who.data(), static_cast<iptr>(who.size()));
  ptr messageText =
      Sstring_utf8(message.data(), static_cast<iptr>(message.size()));
  return Scons(Seof_object, Scons(whoText, messageText));
}

inline ptr errorObject(llvm::Error error) {
  std::string who, message;
  llvm::handleAllErrors(
      std::move(error),
      [&](const CrestError& e) {
        who = e.who();
        message = e.message();
      },
      [&](const llvm::ErrorInfoBase& other) { message = other.message(); });
  return errorObject(who, message);
}

// ---- the C++ value as a Scheme object ----

inline ptr toScheme(ptr value) { return value; }
inline ptr toScheme(uint64_t value) { return Sunsigned64(value); }
inline ptr toScheme(int64_t value) { return Sinteger64(value); }
inline ptr toScheme(uint32_t value) { return Sunsigned64(value); }
inline ptr toScheme(int32_t value) { return Sinteger64(value); }
inline ptr toScheme(bool value) { return value ? Strue : Sfalse; }
inline ptr toScheme(double value) { return Sflonum(value); }
inline ptr toScheme(const char* text) {
  return text ? Sstring_utf8(text, static_cast<iptr>(std::strlen(text)))
              : Sfalse;
}
inline ptr toScheme(const std::string& text) {
  return Sstring_utf8(text.data(), static_cast<iptr>(text.size()));
}
inline ptr toScheme(llvm::Error error) {
  if (!error) {
    return Svoid;
  }
  return errorObject(std::move(error));
}
template <typename T> inline ptr toScheme(llvm::Expected<T> value) {
  if (!value) {
    return errorObject(value.takeError());
  }
  return toScheme(std::move(*value));
}

// ---- the error of a callback ----
//
// Scheme (the guard of a callable) puts the text of the error here through
// crest::error::set and answers the zero value to C++. The first error wins.
// Scheme never reads the slot: the function that was registered with
// register_binding answers it as the error object when the binding returns.

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

inline ptr takeCallbackErrorObject() {
  CallbackError& slot = callbackError();
  ptr object = errorObject(slot.who, slot.message);
  slot = CallbackError();
  return object;
}

// answer(fn): call fn() and answer its result to Scheme (Result.h, top): the
// value as an object, an error as the error object, and the error of a
// callback, if there is one, instead of either.
template <typename Fn> ptr answer(Fn&& fn) {
  using R = std::invoke_result_t<Fn>;
  ptr result;
  if constexpr (std::is_void_v<R>) {
    fn();
    result = Svoid;
  } else {
    result = toScheme(fn());
  }
  if (callbackError().pending) {
    result = takeCallbackErrorObject();
  }
  return result;
}

// ---- register_binding ----

namespace detail {

template <typename F>
struct LambdaTraits : LambdaTraits<decltype(&F::operator())> {};
template <typename C, typename R, typename... A>
struct LambdaTraits<R (C::*)(A...) const> {
  using Result = R;
  using Arguments = std::tuple<A...>;
};

// One trampoline per lambda: the lambda is captureless, so a copy of it in a
// static of the trampoline type (which the lambda's own type makes unique) is
// the lambda.
template <typename F, typename R, typename... A> struct Trampoline {
  static inline std::optional<F> body;
  static ptr call(A... arguments) {
    return answer([&]() -> R { return (*body)(arguments...); });
  }
};

// The names registered with register_binding: those answer a Scheme object, and
// Scheme must call them through crest-foreign-procedure
// (test/bindings/check-ffi-symbols.sls asks, through
// crest::bindings::answersObject).
inline std::set<std::string>& valueBindings() {
  static std::set<std::string> names;
  return names;
}

template <typename F, typename R, typename... A>
void registerTrampoline(const char* name, F&& lambda, std::tuple<A...>*) {
  valueBindings().insert(name);
  Trampoline<std::decay_t<F>, R, A...>::body.emplace(std::forward<F>(lambda));
  Sregister_symbol(name, (void*)&Trampoline<std::decay_t<F>, R, A...>::call);
}

} // namespace detail

// register_binding("mlir::Block::getArgument", [](uint64_t block, int index) ->
// llvm::Expected<uint64_t> { ... }); The lambda is anonymous and captureless
// (Rule 9).
template <typename F> void register_binding(const char* name, F&& lambda) {
  using Traits = detail::LambdaTraits<std::decay_t<F>>;
  detail::registerTrampoline<F, typename Traits::Result>(
      name, std::forward<F>(lambda),
      static_cast<typename Traits::Arguments*>(nullptr));
}

} // namespace crest

#endif // CREST_BINDINGS_SUPPORT_RESULT_H

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#ifndef CREST_BINDINGS_XMM_GUARD_H
#define CREST_BINDINGS_XMM_GUARD_H

#include <optional>
#include <type_traits>
#include <utility>

// Chez Scheme's foreign-callable on Windows x64 does not preserve XMM6-XMM15,
// which that ABI makes non-volatile: after a call into a callable they can be
// zero. C++ compiled for LLVM 23 keeps values in them across a call into a
// callback (a 16-byte Block::iterator, say, that an InsertionGuard restores
// afterwards), so a callable has to be called through withXmmPreserved or
// callForeign, which save and restore them (XmmGuard_x64.asm). Everywhere else
// the call is direct.
#if defined(_WIN64) && defined(_MSC_VER)
extern "C" void crest_preserve_xmm_invoke(void (*fn)(void*), void* context);
#endif

namespace crest {

/// Run `f()` with XMM6-XMM15 preserved, and return what it returns.
template <typename F> inline auto withXmmPreserved(F&& f) {
#if defined(_WIN64) && defined(_MSC_VER)
  using Callable = std::remove_reference_t<F>;
  using Result = std::invoke_result_t<Callable&>;
  if constexpr (std::is_void_v<Result>) {
    crest_preserve_xmm_invoke(
        [](void* context) { (*static_cast<Callable*>(context))(); }, &f);
  } else {
    struct Context {
      Callable* f;
      std::optional<Result>* result;
    };
    std::optional<Result> result;
    Context context{&f, &result};
    crest_preserve_xmm_invoke(
        [](void* raw) {
          auto* c = static_cast<Context*>(raw);
          c->result->emplace((*c->f)());
        },
        &context);
    return std::move(*result);
  }
#else
  return std::forward<F>(f)();
#endif
}

/// Call the entry point of a foreign-callable.
template <typename R, typename... Parameters, typename... Arguments>
inline R callForeign(R (*fn)(Parameters...), Arguments&&... arguments) {
  return withXmmPreserved(
      [&]() -> R { return fn(std::forward<Arguments>(arguments)...); });
}

} // namespace crest

#endif // CREST_BINDINGS_XMM_GUARD_H

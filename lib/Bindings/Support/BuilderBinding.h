/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// register_builder_binding: register one binding that takes a builder, once per
// kind of builder shell. Scheme holds a builder as one of three shells and each
// C++ symbol takes exactly one, so the same body is registered three times
// under three names:
//
//   NAME<OpBuilder>       CrestBox<mlir::OpBuilder>      (atBlockEnd)
//   NAME<RewriterBase*>   CrestBox<mlir::RewriterBase*>  (a pattern's rewriter)
//   NAME<OpBuilder*>      CrestBox<mlir::OpBuilder*>     (a builder MLIR passes
//   to a callback)
//
// A NAME that already ends in '>' takes the kind as its last template argument:
// "mlir::OpBuilder::create<OperationState>" gives
// "...<OperationState,OpBuilder>". The Scheme side (define-builder-binding in
// (mlir support BuilderBinding)) picks the symbol by the shell's type, so the
// body below only ever sees an mlir::OpBuilder&.
//
// The body is a non-capturing lambda whose first parameter is
// `mlir::OpBuilder&`:
//
//   register_builder_binding(
//       "mlir::arith::AddFOp::create",
//       [](mlir::OpBuilder& builder, uint64_t loc_ptr, ...) -> ptr { ...
//       });

#ifndef CREST_BINDINGS_SUPPORT_BUILDERBINDING_H
#define CREST_BINDINGS_SUPPORT_BUILDERBINDING_H

#include "CrestObject.h"
#include "Result.h"
#include "SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/PatternMatch.h"
#include <cstdint>
#include <deque>
#include <optional>
#include <string>
#include <utility>

namespace crest {
namespace detail {

template <typename Shell> mlir::OpBuilder* builder_inner(uint64_t handle);

template <>
inline mlir::OpBuilder*
builder_inner<CrestBox<mlir::OpBuilder>>(uint64_t handle) {
  return CrestBox<mlir::OpBuilder>::inner(handle);
}

// RewriterBase& converts to OpBuilder& statically, which adjusts the address:
// RewriterBase is polymorphic, so its OpBuilder base is not at offset 0.
template <>
inline mlir::OpBuilder*
builder_inner<CrestBox<mlir::RewriterBase*>>(uint64_t handle) {
  mlir::RewriterBase* rewriter = CrestBox<mlir::RewriterBase*>::inner(handle);
  return rewriter ? static_cast<mlir::OpBuilder*>(rewriter) : nullptr;
}

template <>
inline mlir::OpBuilder*
builder_inner<CrestBox<mlir::OpBuilder*>>(uint64_t handle) {
  return CrestBox<mlir::OpBuilder*>::inner(handle);
}

// The body and the binding name live in statics per lambda type, because a C
// symbol cannot carry state. Chez keeps the registered name pointers, so the
// names live forever.
template <typename F, typename... Args> struct BuilderBinding {
  static inline std::optional<F> body;
  static inline std::string name;

  // The shell is checked first: a handle of the wrong kind answers an error;
  // then the body runs with the builder and answers a Scheme object.
  template <typename Shell> static ptr call(uint64_t handle, Args... args) {
    mlir::OpBuilder* builder = builder_inner<Shell>(handle);
    if (!builder) {
      return scheme_error(name.c_str(), "not a builder of the expected kind");
    }
    return (*body)(*builder, std::forward<Args>(args)...);
  }
};

inline const char* keep(std::string s) {
  static std::deque<std::string> names;
  names.push_back(std::move(s));
  return names.back().c_str();
}

inline std::string with_kind(const std::string& name, const char* kind) {
  if (!name.empty() && name.back() == '>') {
    return name.substr(0, name.size() - 1) + "," + kind + ">";
  }
  return name + "<" + kind + ">";
}

template <typename F, typename... Args>
void register_builder_binding_impl(const char* name, F body,
                                   ptr (F::*)(mlir::OpBuilder&, Args...)
                                       const) {
  using Binding = BuilderBinding<F, Args...>;
  Binding::body.emplace(std::move(body));
  Binding::name = name;
  auto registerKind = [&](const char* kind, void* function) {
    const char* symbol = keep(with_kind(name, kind));
    Sregister_symbol(symbol, function);
  };
  registerKind("OpBuilder",
               reinterpret_cast<void*>(
                   &Binding::template call<CrestBox<mlir::OpBuilder>>));
  registerKind("RewriterBase*",
               reinterpret_cast<void*>(
                   &Binding::template call<CrestBox<mlir::RewriterBase*>>));
  registerKind("OpBuilder*",
               reinterpret_cast<void*>(
                   &Binding::template call<CrestBox<mlir::OpBuilder*>>));
}

} // namespace detail

template <typename F> void register_builder_binding(const char* name, F body) {
  detail::register_builder_binding_impl(name, std::move(body), &F::operator());
}

} // namespace crest

#endif // CREST_BINDINGS_SUPPORT_BUILDERBINDING_H

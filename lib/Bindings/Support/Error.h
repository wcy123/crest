/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// The error state of a C++ function that Scheme calls
// (plans/04-errors-are-values.md).
//
// C++ never raises a Scheme error. A function that can fail returns llvm::Error
// (no result) or llvm::Expected<T> (a result); a binding answers the error to
// Scheme as a value (Result.h), and Scheme raises it after the C++ call has
// returned. So the destructors of every frame run, and no error crosses a C
// function. This header does not depend on Chez Scheme.

#ifndef CREST_BINDINGS_SUPPORT_ERROR_H
#define CREST_BINDINGS_SUPPORT_ERROR_H

#include "llvm/Support/Error.h"
#include "llvm/Support/raw_ostream.h"
#include <string>
#include <system_error>

namespace crest {

// An error with the name of the binding that failed
// ("mlir::Block::getArgument") and the text.
class CrestError : public llvm::ErrorInfo<CrestError> {
public:
  static inline char ID = 0;

  CrestError(std::string who, std::string message)
      : who_(std::move(who)), message_(std::move(message)) {}

  const std::string& who() const { return who_; }
  void log(llvm::raw_ostream& os) const override {
    os << who_ << ": " << message_;
  }
  std::string message() const override { return message_; }
  std::error_code convertToErrorCode() const override {
    return llvm::inconvertibleErrorCode();
  }

private:
  std::string who_;
  std::string message_;
};

// `return fail("mlir::Block::getArgument", "block pointer is null");` in a
// function that answers llvm::Error or llvm::Expected<T>. The text is a Twine,
// so `"index " + Twine(i)` works.
inline llvm::Error fail(const char* who, const llvm::Twine& message) {
  return llvm::make_error<CrestError>(who, message.str());
}

// CREST_TRY(name, expression): `expression` answers llvm::Expected<T>; on an
// error, the enclosing function returns it (it must answer llvm::Error or
// llvm::Expected<U>); otherwise `name` is bound to the value (a T&, a copy of a
// small T is fine through `auto`).
#define CREST_TRY(name, expression)                                            \
  auto name##_crest_try = (expression);                                        \
  if (!name##_crest_try)                                                       \
    return name##_crest_try.takeError();                                       \
  auto& name = *name##_crest_try

} // namespace crest

#endif // CREST_BINDINGS_SUPPORT_ERROR_H

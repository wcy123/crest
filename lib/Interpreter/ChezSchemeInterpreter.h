/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#ifndef CREST_INTERPRETER_CHEZSCHEMEINTERPRETER_H
#define CREST_INTERPRETER_CHEZSCHEMEINTERPRETER_H

#include <memory>
#include <string>

#include "../Bindings/Support/SchemeWrapper.h"

namespace mlir {
class Operation;
} // namespace mlir

namespace crest {

template <typename T> struct WeakSingleton;

enum class SchemeLogLevel {
  Trace = 0,
  Debug = 1,
  Info = 2,
  Warning = 3,
  Error = 4,
  Fatal = 5
};

// Register all MLIR foreign functions accessible from Scheme.
// Called once during Scheme runtime initialization.
void registerMlirForeignFunctions();

/// Chez Scheme runtime managed via WeakSingleton.
/// Use instance() to obtain the shared runtime; it is initialized on first
/// call and destroyed when all shared_ptr holders release it.
class ChezSchemeInterpreter {
public:
  // Only public creation point. Returns the live instance, creating and
  // initializing it if none exists. logLevel is used only on first creation.
  // initHook is called once during Sbuild_heap to register foreign functions;
  // pass crest::registerMlirForeignFunctions from CrestBindings.
  static std::shared_ptr<ChezSchemeInterpreter>
  instance(SchemeLogLevel logLevel = SchemeLogLevel::Warning,
           void (*initHook)() = nullptr);

  // Private-tag constructor — both the tag type and constructor are public so
  // std::make_shared (stdlib internals) can reach them. Protection comes from
  // the fact that PrivateTag's constructor is private: only friends
  // (WeakSingleton) can construct a PrivateTag and thus call this constructor.
  struct PrivateTag {
  private:
    friend struct WeakSingleton<ChezSchemeInterpreter>;
    explicit PrivateTag() = default;
  };
  ChezSchemeInterpreter(PrivateTag, SchemeLogLevel logLevel,
                        void (*initHook)());
  ~ChezSchemeInterpreter();

  // Non-copyable, non-movable
  ChezSchemeInterpreter(const ChezSchemeInterpreter&) = delete;
  ChezSchemeInterpreter& operator=(const ChezSchemeInterpreter&) = delete;

  void setLogLevel(SchemeLogLevel level);
  SchemeLogLevel getLogLevel() const;

  bool eval(const char* code);

  // Import a Scheme library by its slash-separated name.
  // "passes/my-rewrite" → (import (passes my-rewrite))
  // Returns false if the import fails.
  bool importLibrary(const std::string& slashSeparatedName);
  void addLibraryPath(const char* src_path, const char* bin_path);

  // For debugging only — returns a human-readable string of all (src . bin)
  // pairs in Chez Scheme's library-directories parameter.
  // e.g. "(/a/scheme . /a/bin), (/b/scheme . /b/bin)"
  std::string getLibraryDirectories() const;

private:
  friend struct WeakSingleton<ChezSchemeInterpreter>;

  SchemeLogLevel logLevel_;
};

// Parse a log-level string ("trace", "debug", "info", "warning", "error",
// "fatal") to SchemeLogLevel. Defaults to Warning for unknown strings.
SchemeLogLevel parseLogLevel(const std::string& level);

} // namespace crest

#endif // CREST_INTERPRETER_CHEZSCHEMEINTERPRETER_H

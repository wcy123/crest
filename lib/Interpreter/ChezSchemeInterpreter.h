/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#ifndef CREST_INTERPRETER_CHEZSCHEMEINTERPRETER_H
#define CREST_INTERPRETER_CHEZSCHEMEINTERPRETER_H

#include <memory>
#include <string>
#include <vector>

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

  bool load(const char* scriptPath);
  bool eval(const char* code);

  ptr makeString(const char* str);
  ptr makeInteger(long value);

  std::string callFunction(const char* functionName,
                           const std::vector<ptr>& args);

  void callPassFunction(const char* functionName, mlir::Operation* op);

  void addLibraryPath(const char* src_path, const char* bin_path);

private:
  friend struct WeakSingleton<ChezSchemeInterpreter>;

  SchemeLogLevel logLevel_;
};

// Parse a log-level string ("trace", "debug", "info", "warning", "error",
// "fatal") to SchemeLogLevel. Defaults to Warning for unknown strings.
SchemeLogLevel parseLogLevel(const std::string& level);

} // namespace crest

#endif // CREST_INTERPRETER_CHEZSCHEMEINTERPRETER_H

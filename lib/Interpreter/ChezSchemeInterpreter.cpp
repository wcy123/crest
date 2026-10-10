/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#include "ChezSchemeInterpreter.h"

#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/Process.h"
#include "llvm/Support/Program.h"
#include "llvm/Support/raw_ostream.h"
#include "mlir/IR/Operation.h"

// Note: scheme.h already included via ChezSchemeInterpreter.h
// Do NOT include it again here to avoid redefinition errors with static inline
// functions

#include "ChezBootPetite.h"
#include "ChezBootScheme.h"
#ifdef CREST_BOOT_EMBEDDED
#  include "CrestBoot.h"
#endif

#include <cassert>
#include <memory>

namespace {

const size_t petite_boot_size = sizeof(petite_boot_data) - 1;
const size_t scheme_boot_size = sizeof(scheme_boot_data) - 1;
#ifdef CREST_BOOT_EMBEDDED
const size_t crest_boot_size = sizeof(crest_boot_data) - 1;
#endif

// Set by ChezSchemeInterpreter constructor; called once from Sbuild_heap.
static void (*g_init_hook)() = nullptr;
static void custom_init() {
  if (g_init_hook) {
    g_init_hook();
  }
}

} // anonymous namespace

namespace crest {

// WeakSingleton lives in namespace crest to match the friend declaration in
// ChezSchemeInterpreter.h. Defined here (not in the header) to keep it
// private to this translation unit.
// ChezScheme cannot be re-initialized in the same process (Sscheme_init aborts
// if called twice). Use a strong singleton so the interpreter persists across
// multiple --split-input-file sections processed in a single crest-opt run.
template <typename T> struct WeakSingleton {
  static std::shared_ptr<T> the_instance_;

  template <typename... Args> static std::shared_ptr<T> create(Args&&... args) {
    if (!the_instance_) {
      // PrivateTag{} is constructed here — inside WeakSingleton which is a
      // friend of both ChezSchemeInterpreter and PrivateTag.
      the_instance_ = std::make_shared<T>(typename T::PrivateTag{},
                                          std::forward<Args>(args)...);
    }
    return the_instance_;
  }
};

template <typename T> std::shared_ptr<T> WeakSingleton<T>::the_instance_;

} // namespace crest

namespace crest {

// ─── Factory
// ──────────────────────────────────────────────────────────────────

std::shared_ptr<ChezSchemeInterpreter>
ChezSchemeInterpreter::instance(SchemeLogLevel logLevel, void (*initHook)()) {
  return WeakSingleton<ChezSchemeInterpreter>::create(logLevel, initHook);
}

// ─── Construction / Destruction
// ───────────────────────────────────────────────

ChezSchemeInterpreter::ChezSchemeInterpreter(PrivateTag,
                                             SchemeLogLevel logLevel,
                                             void (*initHook)())
    : logLevel_(logLevel) {
  g_init_hook = initHook;
  if (logLevel_ <= SchemeLogLevel::Debug) {
    llvm::errs()
        << "[debug] ChezSchemeInterpreter: Initializing Chez Scheme runtime\n";
  }

  Sscheme_init(nullptr);

  if (logLevel_ <= SchemeLogLevel::Debug) {
    llvm::errs()
        << "[debug] ChezSchemeInterpreter: Registering embedded boot files\n";
  }

  Sregister_boot_file_bytes(
      "petite.boot",
      const_cast<void*>(static_cast<const void*>(petite_boot_data)),
      petite_boot_size);
  Sregister_boot_file_bytes(
      "scheme.boot",
      const_cast<void*>(static_cast<const void*>(scheme_boot_data)),
      scheme_boot_size);
#ifdef CREST_BOOT_EMBEDDED
  Sregister_boot_file_bytes(
      "crest.boot",
      const_cast<void*>(static_cast<const void*>(crest_boot_data)),
      crest_boot_size);
#endif

  if (logLevel_ <= SchemeLogLevel::Debug) {
    llvm::errs() << "[debug] ChezSchemeInterpreter: Building heap\n";
  }

  Sbuild_heap(nullptr, custom_init);

#ifndef CREST_BOOT_EMBEDDED
  // Development mode: load .sls files from the source tree at runtime.
  // CREST_SCHEME_BINARY_DIR overrides the compiled .so cache directory at
  // runtime — useful for tests that need an isolated cache (e.g. to force
  // recompilation with CREST_DEBUG_MATCH=1 without polluting the shared dir).
  const std::string schemeBinaryDir =
      llvm::sys::Process::GetEnv("CREST_SCHEME_BINARY_DIR")
          .value_or(std::string(SCHEME_BINARY_DIR));
  addLibraryPath(SCHEME_LIBRARIES_DIR, schemeBinaryDir.c_str());
  addLibraryPath(RIME_DIR, schemeBinaryDir.c_str());
#endif

  // CREST_PATH: optional colon-separated (POSIX) or semicolon-separated
  // (Windows) list of additional .sls source directories, similar to PATH.
  if (auto val = llvm::sys::Process::GetEnv("CREST_PATH")) {
    llvm::SmallVector<llvm::StringRef, 8> dirs;
    llvm::StringRef(*val).split(dirs, llvm::sys::EnvPathSeparator);
    for (auto dir : dirs) {
      if (!dir.empty()) {
        addLibraryPath(dir.str().c_str(), schemeBinaryDir.c_str());
      }
    }
  }

  if (logLevel_ <= SchemeLogLevel::Info) {
    llvm::errs() << "[info] ChezSchemeInterpreter: Initialization complete\n";
  }
}

ChezSchemeInterpreter::~ChezSchemeInterpreter() {
  if (logLevel_ <= SchemeLogLevel::Debug) {
    llvm::errs()
        << "[debug] ChezSchemeInterpreter: Shutting down Scheme runtime\n";
  }
  // Chez Scheme does not require explicit cleanup
}

// ─── Configuration
// ────────────────────────────────────────────────────────────

SchemeLogLevel parseLogLevel(const std::string& level) {
  if (level == "trace") {
    return SchemeLogLevel::Trace;
  }
  if (level == "debug") {
    return SchemeLogLevel::Debug;
  }
  if (level == "info") {
    return SchemeLogLevel::Info;
  }
  if (level == "warning") {
    return SchemeLogLevel::Warning;
  }
  if (level == "error") {
    return SchemeLogLevel::Error;
  }
  if (level == "fatal") {
    return SchemeLogLevel::Fatal;
  }
  llvm::errs() << "Warning: unknown log level '" << level
               << "', defaulting to 'warning'\n";
  return SchemeLogLevel::Warning;
}

void ChezSchemeInterpreter::setLogLevel(SchemeLogLevel level) {
  logLevel_ = level;
}

SchemeLogLevel ChezSchemeInterpreter::getLogLevel() const { return logLevel_; }

// ─── Library paths
// ────────────────────────────────────────────────────────────

void ChezSchemeInterpreter::addLibraryPath(const char* src_path,
                                           const char* bin_path) {
  ptr lib_dirs_param =
      Stop_level_value(Sstring_to_symbol("library-directories"));
  ptr current_dirs = Scall0(lib_dirs_param);
  ptr pair = Scons(Sstring(src_path), Sstring(bin_path));
  Scall1(lib_dirs_param, Scons(pair, current_dirs));

  if (logLevel_ <= SchemeLogLevel::Debug) {
    llvm::errs() << "[debug] ChezSchemeInterpreter: added library path ("
                 << src_path << " . " << bin_path << ")\n";
  }
}

std::string ChezSchemeInterpreter::getLibraryDirectories() const {
  auto str = [](ptr s) {
    std::string out;
    iptr len = Sstring_length(s);
    out.reserve(len);
    for (iptr i = 0; i < len; ++i) {
      out += static_cast<char>(Schar_value(Sstring_ref(s, i)));
    }
    return out;
  };
  ptr lib_dirs = scheme_call("library-directories");
  std::string result;
  for (ptr p = lib_dirs; p != Snil && Spairp(p); p = Scdr(p)) {
    ptr pair = Scar(p);
    if (!Spairp(pair) || !Sstringp(Scar(pair)) || !Sstringp(Scdr(pair))) {
      continue;
    }
    if (!result.empty()) {
      result += ", ";
    }
    result += "(" + str(Scar(pair)) + " . " + str(Scdr(pair)) + ")";
  }
  return result;
}

// ─── Script / eval
// ────────────────────────────────────────────────────────────

bool ChezSchemeInterpreter::importLibrary(
    const std::string& slashSeparatedName) {
  std::string lib = slashSeparatedName;
  std::replace(lib.begin(), lib.end(), '/', ' ');
  std::string importCode = "(import (" + lib + "))";
  return eval(importCode.c_str());
}

bool ChezSchemeInterpreter::eval(const char* code) {
  ptr port = scheme_call("open-string-input-port", Sstring(code));
  ptr expr = scheme_call("read", port);
  scheme_call("eval", expr);
  return true;
}

} // namespace crest

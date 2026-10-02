/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#include "ChezSchemeInterpreter.h"

#include "llvm/Support/raw_ostream.h"
#include "mlir/IR/Operation.h"

// Note: scheme.h already included via ChezSchemeInterpreter.h
// Do NOT include it again here to avoid redefinition errors with static inline functions

#include "ChezBootPetite.h"
#include "ChezBootScheme.h"

#include <cassert>
#include <memory>

namespace {

const size_t petite_boot_size = sizeof(petite_boot_data) - 1;
const size_t scheme_boot_size = sizeof(scheme_boot_data) - 1;

// Set by ChezSchemeInterpreter constructor; called once from Sbuild_heap.
static void (*g_init_hook)() = nullptr;
static void custom_init() {
  if (g_init_hook) g_init_hook();
}

} // anonymous namespace

namespace crest {

// WeakSingleton lives in namespace crest to match the friend declaration in
// ChezSchemeInterpreter.h. Defined here (not in the header) to keep it
// private to this translation unit.
template <typename T>
struct WeakSingleton {
  static std::weak_ptr<T> the_instance_;

  template <typename... Args>
  static std::shared_ptr<T> create(Args&&... args) {
    std::shared_ptr<T> ret;
    if (the_instance_.expired()) {
      ret = std::make_shared<T>(std::forward<Args>(args)...);
      the_instance_ = ret;
    }
    ret = the_instance_.lock();
    assert(ret != nullptr);
    return ret;
  }
};

template <typename T>
std::weak_ptr<T> WeakSingleton<T>::the_instance_;

} // namespace crest

namespace crest {

// ─── Factory ──────────────────────────────────────────────────────────────────

std::shared_ptr<ChezSchemeInterpreter>
ChezSchemeInterpreter::instance(SchemeLogLevel logLevel, void (*initHook)()) {
  return WeakSingleton<ChezSchemeInterpreter>::create(logLevel, initHook);
}

// ─── Construction / Destruction ───────────────────────────────────────────────

ChezSchemeInterpreter::ChezSchemeInterpreter(SchemeLogLevel logLevel,
                                             void (*initHook)())
    : logLevel_(logLevel) {
  g_init_hook = initHook;
  if (logLevel_ <= SchemeLogLevel::Debug)
    llvm::errs() << "[debug] ChezSchemeInterpreter: Initializing Chez Scheme runtime\n";

  Sscheme_init(nullptr);

  if (logLevel_ <= SchemeLogLevel::Debug)
    llvm::errs() << "[debug] ChezSchemeInterpreter: Registering embedded boot files\n";

  Sregister_boot_file_bytes("petite.boot",
      const_cast<void*>(static_cast<const void*>(petite_boot_data)),
      petite_boot_size);
  Sregister_boot_file_bytes("scheme.boot",
      const_cast<void*>(static_cast<const void*>(scheme_boot_data)),
      scheme_boot_size);

  if (logLevel_ <= SchemeLogLevel::Debug)
    llvm::errs() << "[debug] ChezSchemeInterpreter: Building heap\n";

  Sbuild_heap(nullptr, custom_init);

  addLibraryPath(SCHEME_LIBRARIES_DIR, SCHEME_BINARY_DIR);
  addLibraryPath(RIME_DIR, RIME_DIR);

  if (logLevel_ <= SchemeLogLevel::Info)
    llvm::errs() << "[info] ChezSchemeInterpreter: Initialization complete\n";
}

ChezSchemeInterpreter::~ChezSchemeInterpreter() {
  if (logLevel_ <= SchemeLogLevel::Debug)
    llvm::errs() << "[debug] ChezSchemeInterpreter: Shutting down Scheme runtime\n";
  // Chez Scheme does not require explicit cleanup
}

// ─── Configuration ────────────────────────────────────────────────────────────

SchemeLogLevel parseLogLevel(const std::string& level) {
  if (level == "trace")   return SchemeLogLevel::Trace;
  if (level == "debug")   return SchemeLogLevel::Debug;
  if (level == "info")    return SchemeLogLevel::Info;
  if (level == "warning") return SchemeLogLevel::Warning;
  if (level == "error")   return SchemeLogLevel::Error;
  if (level == "fatal")   return SchemeLogLevel::Fatal;
  llvm::errs() << "Warning: unknown log level '" << level
               << "', defaulting to 'warning'\n";
  return SchemeLogLevel::Warning;
}

void ChezSchemeInterpreter::setLogLevel(SchemeLogLevel level) {
  logLevel_ = level;
}

SchemeLogLevel ChezSchemeInterpreter::getLogLevel() const {
  return logLevel_;
}

// ─── Library paths ────────────────────────────────────────────────────────────

void ChezSchemeInterpreter::addLibraryPath(const char* src_path, const char* bin_path) {
  ptr lib_dirs_param = Stop_level_value(Sstring_to_symbol("library-directories"));
  ptr current_dirs = Scall0(lib_dirs_param);
  ptr pair = Scons(Sstring(src_path), Sstring(bin_path));
  Scall1(lib_dirs_param, Scons(pair, current_dirs));

  if (logLevel_ <= SchemeLogLevel::Debug)
    llvm::errs() << "[debug] ChezSchemeInterpreter: added library path ("
                 << src_path << " . " << bin_path << ")\n";
}

// ─── Script / eval ────────────────────────────────────────────────────────────

bool ChezSchemeInterpreter::load(const char* scriptPath) {
  ptr load_sym = Stop_level_value(Sstring_to_symbol("load"));
  Scall1(load_sym, Sstring(scriptPath));
  return true;
}

bool ChezSchemeInterpreter::eval(const char* code) {
  ptr eval_sym     = Stop_level_value(Sstring_to_symbol("eval"));
  ptr read_sym     = Stop_level_value(Sstring_to_symbol("read"));
  ptr open_port_sym = Stop_level_value(Sstring_to_symbol("open-string-input-port"));

  ptr port = Scall1(open_port_sym, Sstring(code));
  ptr expr = Scall1(read_sym, port);
  Scall1(eval_sym, expr);
  return true;
}

// ─── Value helpers ────────────────────────────────────────────────────────────

ptr ChezSchemeInterpreter::makeString(const char* str) {
  return Sstring(str);
}

ptr ChezSchemeInterpreter::makeInteger(long value) {
  return Sinteger(value);
}

// ─── Function calls ───────────────────────────────────────────────────────────

std::string ChezSchemeInterpreter::callFunction(const char* functionName,
                                                const std::vector<ptr>& args) {
  ptr func = Stop_level_value(Sstring_to_symbol(functionName));
  if (func == Sfalse)
    return "";

  ptr args_list = Snil;
  for (auto it = args.rbegin(); it != args.rend(); ++it)
    args_list = Scons(*it, args_list);

  ptr apply_proc = Stop_level_value(Sstring_to_symbol("apply"));
  ptr result = Scall2(apply_proc, func, args_list);

  ptr string_p = Stop_level_value(Sstring_to_symbol("string?"));
  if (Scall1(string_p, result) != Sfalse) {
    iptr len = Sstring_length(result);
    std::string str;
    str.reserve(len);
    for (iptr i = 0; i < len; i++)
      str.push_back(static_cast<char>(Sstring_ref(result, i)));
    return str;
  }

  return "";
}

void ChezSchemeInterpreter::callPassFunction(const char* functionName,
                                            mlir::Operation* op) {
  ptr func = Stop_level_value(Sstring_to_symbol(functionName));
  if (func == Sfalse) {
    llvm::errs() << "Warning: Scheme function '" << functionName << "' not found\n";
    return;
  }
  ptr schemeOp = Sunsigned64(reinterpret_cast<uint64_t>(op));
  Scall1(func, schemeOp);
}

} // namespace crest

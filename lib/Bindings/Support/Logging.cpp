/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#include "../../Interpreter/ChezSchemeInterpreter.h"
#include "SchemeWrapper.h"
#include "llvm/Support/raw_ostream.h"

#define DEBUG_TYPE "scheme-logging-bindings"

// Note: scheme.h included via SchemeWrapper.h

extern "C" {

void mlir_support_logging_trace(const char* msg) {
  if (crest::ChezSchemeInterpreter::instance()->getLogLevel() <=
      crest::SchemeLogLevel::Trace) {
    llvm::errs() << "[trace] " << msg << "\n";
  }
}

void mlir_support_logging_debug(const char* msg) {
  if (crest::ChezSchemeInterpreter::instance()->getLogLevel() <=
      crest::SchemeLogLevel::Debug) {
    llvm::errs() << "[debug] " << msg << "\n";
  }
}

void mlir_support_logging_info(const char* msg) {
  if (crest::ChezSchemeInterpreter::instance()->getLogLevel() <=
      crest::SchemeLogLevel::Info) {
    llvm::errs() << "[info] " << msg << "\n";
  }
}

void mlir_support_logging_warning(const char* msg) {
  if (crest::ChezSchemeInterpreter::instance()->getLogLevel() <=
      crest::SchemeLogLevel::Warning) {
    llvm::errs() << "[warning] " << msg << "\n";
  }
}

void mlir_support_logging_error(const char* msg) {
  if (crest::ChezSchemeInterpreter::instance()->getLogLevel() <=
      crest::SchemeLogLevel::Error) {
    llvm::errs() << "[error] " << msg << "\n";
  }
}

void mlir_support_logging_fatal(const char* msg) {
  if (crest::ChezSchemeInterpreter::instance()->getLogLevel() <=
      crest::SchemeLogLevel::Fatal) {
    llvm::errs() << "[fatal] " << msg << "\n";
  }
}

} // extern "C"

namespace crest {

void registerLoggingBindings() {
  Sregister_symbol("mlir_support_logging_trace",
                   (void*)::mlir_support_logging_trace);
  Sregister_symbol("mlir_support_logging_debug",
                   (void*)::mlir_support_logging_debug);
  Sregister_symbol("mlir_support_logging_info",
                   (void*)::mlir_support_logging_info);
  Sregister_symbol("mlir_support_logging_warning",
                   (void*)::mlir_support_logging_warning);
  Sregister_symbol("mlir_support_logging_error",
                   (void*)::mlir_support_logging_error);
  Sregister_symbol("mlir_support_logging_fatal",
                   (void*)::mlir_support_logging_fatal);
}

} // namespace crest

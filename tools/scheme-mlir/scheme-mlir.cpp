/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- scheme-mlir.cpp - Scheme interpreter with MLIR bindings ------------===//
//
// Behaves like `chezscheme --script`: loads a top-level Scheme program and
// exposes trailing argv to (command-line-arguments). The Scheme program owns
// its CLI.
//
// Usage: scheme-mlir <library> [args...]
//
//===----------------------------------------------------------------------===//

#include "../../lib/Bindings/Support/SchemeWrapper.h"
#include "../../lib/Interpreter/ChezSchemeInterpreter.h"

#include "llvm/Support/raw_ostream.h"

int main(int argc, char** argv) {
  if (argc < 2) {
    llvm::errs() << "Usage: scheme-mlir <library> [args...]\n";
    return 1;
  }

  const char* library = argv[1];

  auto interp = crest::ChezSchemeInterpreter::instance(
      crest::SchemeLogLevel::Warning, crest::registerMlirForeignFunctions);

  // Set (command-line-arguments) to argv[2..] — mirrors chezscheme --script.
  ptr args_list = Snil;
  for (int i = argc - 1; i >= 2; --i) {
    args_list = Scons(Sstring(argv[i]), args_list);
  }
  ptr cla_param = Stop_level_value(Sstring_to_symbol("command-line-arguments"));
  if (cla_param != Sfalse) {
    scheme_call(cla_param, args_list);
  }

  interp->loadFile(library);

  return 0;
}

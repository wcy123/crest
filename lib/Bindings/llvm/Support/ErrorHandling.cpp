/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors llvm/Support/ErrorHandling.h
//
// There is no header of ours for it: a
// lib/Bindings/llvm/Support/ErrorHandling.h would hide the one of LLVM from
// every file that includes it by that name.

#include "llvm/Support/ErrorHandling.h"
#include "../../Support/SchemeWrapper.h"

namespace crest {

void registerLLVMErrorHandlingBindings() {
  // llvm::report_fatal_error (string text)
  //
  // Prints "LLVM ERROR: <text>" and ends the process with exit code 1 (no crash
  // report, no abort). It never returns: the destructors of the frames above do
  // not run, so call it only when there is nothing to free that matters, as in
  // the guard of a callback that has no place to answer an error (Rule 20).
  Sregister_symbol(
      "llvm::report_fatal_error", (void*)+[](const char* text) -> ptr {
        llvm::report_fatal_error(text, false);
      });
}

} // namespace crest

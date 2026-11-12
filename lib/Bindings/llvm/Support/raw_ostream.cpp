/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors llvm/Support/raw_ostream.h
//
// There is no header of ours for it: a lib/Bindings/llvm/Support/raw_ostream.h
// would hide the one of LLVM from every file that includes it by that name.

#include "llvm/Support/raw_ostream.h"
#include "../../Support/Result.h"
#include "../../Support/SchemeWrapper.h"

namespace crest {

void registerLLVMRawOstreamBindings() {
  // llvm::raw_ostream::write (uptr stream) (string text)
  //
  // `stream` is a raw_ostream that C++ gave Scheme for the length of a
  // callback, such as mlir::AsmPrinter::getStream.
  register_binding("llvm::raw_ostream::write",
                   [](uint64_t stream_ptr, const char* text) -> llvm::Error {
                     if (!stream_ptr) {
                       return fail("llvm::raw_ostream::write",
                                   llvm::Twine("stream pointer is null"));
                     }
                     *reinterpret_cast<llvm::raw_ostream*>(stream_ptr) << text;
                     return llvm::Error::success();
                   });
}

} // namespace crest

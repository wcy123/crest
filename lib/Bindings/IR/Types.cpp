/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Types.h

#include "Types.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "llvm/Support/raw_ostream.h"
#include "mlir/IR/Types.h"

namespace crest {

void registerIRTypeBindings() {
  register_binding("mlir::Type::getContext",
                   [](uint64_t type_ptr) -> llvm::Expected<uint64_t> {
                     if (!type_ptr) {
                       return fail("mlir::Type::getContext",
                                   llvm::Twine("type pointer is null"));
                     }
                     return reinterpret_cast<uint64_t>(
                         mlir::Type::getFromOpaquePointer(
                             reinterpret_cast<const void*>(type_ptr))
                             .getContext());
                   });
  // The type in its textual form, as MLIR prints it.
  register_binding("mlir::Type::print", [](uint64_t type_ptr) -> ptr {
    if (!type_ptr) {
      return Sstring("");
    }
    std::string str;
    llvm::raw_string_ostream os(str);
    mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(type_ptr))
        .print(os);
    return Sstring(str.c_str());
  });
}

} // namespace crest

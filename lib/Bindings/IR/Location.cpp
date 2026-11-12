/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Location.h — Location constructors.

#include "Location.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/MLIRContext.h"

namespace crest {

void registerIRLocationBindings() {
  Sregister_symbol(
      "mlir::UnknownLoc::get", (void*)+[](uint64_t ctx_ptr) -> ptr {
        if (!ctx_ptr) {
          return scheme_error("mlir::UnknownLoc::get", "ctx must not be null");
        }
        auto* ctx = crest::as_context(ctx_ptr);
        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::UnknownLoc::get(ctx).getAsOpaquePointer()));
      });
  Sregister_symbol(
      "mlir::FileLineColLoc::get",
      (void*)+[](uint64_t ctx_ptr, const char* filename, unsigned line,
                 unsigned col) -> ptr {
        if (!ctx_ptr) {
          return scheme_error("mlir::FileLineColLoc::get",
                              "ctx must not be null");
        }
        auto* ctx = crest::as_context(ctx_ptr);
        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::FileLineColLoc::get(ctx, filename, line, col)
                .getAsOpaquePointer()));
      });
}

} // namespace crest

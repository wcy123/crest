/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Location.h — Location constructors.

#include "Location.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/MLIRContext.h"

namespace crest {

void registerIRLocationBindings() {
  Sregister_symbol(
      "mlir::UnknownLoc::get", (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::UnknownLoc::get", "ctx must not be null");
          return 0;
        }
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        return reinterpret_cast<uint64_t>(
            mlir::UnknownLoc::get(ctx).getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::FileLineColLoc::get",
      (void*)+[](uint64_t ctx_ptr, const char* filename, unsigned line,
                 unsigned col) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::FileLineColLoc::get", "ctx must not be null");
          return 0;
        }
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        return reinterpret_cast<uint64_t>(
            mlir::FileLineColLoc::get(ctx, filename, line, col)
                .getAsOpaquePointer());
      });
}

} // namespace crest

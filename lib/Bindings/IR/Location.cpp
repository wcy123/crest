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
  register_binding(
      "mlir::UnknownLoc::get",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::UnknownLoc::get",
                      llvm::Twine("ctx must not be null"));
          return 0;
        }
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            mlir::UnknownLoc::get(ctx).getAsOpaquePointer());
      });
  register_binding(
      "mlir::FileLineColLoc::get",
      [](uint64_t ctx_ptr, const char* filename, unsigned line,
         unsigned col) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::FileLineColLoc::get",
                      llvm::Twine("ctx must not be null"));
          return 0;
        }
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            mlir::FileLineColLoc::get(ctx, filename, line, col)
                .getAsOpaquePointer());
      });
}

} // namespace crest

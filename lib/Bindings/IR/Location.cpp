/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Location.h — Location constructors.

#include "Location.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/MLIRContext.h"

extern "C" {

// mlir::UnknownLoc::get(ctx) — create an unknown/unspecified location.
static uint64_t mlir_ir_unknown_loc_get(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir::UnknownLoc::get", "ctx must not be null");
    return 0; // unreachable
  }
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(
      mlir::UnknownLoc::get(ctx).getAsOpaquePointer());
}

// mlir::FileLineColLoc::get(ctx, filename, line, col) — create a file/line/col
// location.
static uint64_t mlir_ir_file_line_col_loc_get(uint64_t ctx_ptr,
                                              const char* filename,
                                              unsigned line, unsigned col) {
  if (!ctx_ptr) {
    scheme_error("mlir::FileLineColLoc::get", "ctx must not be null");
    return 0; // unreachable
  }
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(
      mlir::FileLineColLoc::get(ctx, filename, line, col).getAsOpaquePointer());
}

} // extern "C"

namespace crest {

void registerIRLocationBindings() {
  Sregister_symbol("mlir::UnknownLoc::get", (void*)::mlir_ir_unknown_loc_get);
  Sregister_symbol("mlir::FileLineColLoc::get",
                   (void*)::mlir_ir_file_line_col_loc_get);
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Diagnostics.h

#include "Diagnostics.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Diagnostics.h"
#include "mlir/IR/Location.h"

namespace crest {

void registerIRDiagnosticsBindings() {
  // mlir::emitError(Location, message): report an error at a location through
  // the context's diagnostic engine. (location message) → void
  Sregister_symbol(
      "mlir::emitError",
      (void*)+[](uint64_t loc_ptr, const char* message) -> ptr {
        if (!loc_ptr) {
          return scheme_error("mlir::emitError", "location must not be null");
        }
        auto loc_attr = mlir::dyn_cast_or_null<mlir::LocationAttr>(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(loc_ptr)));
        if (!loc_attr) {
          return scheme_error("mlir::emitError", "not a location");
        }
        mlir::Location loc = loc_attr;
        mlir::emitError(loc, message);
        return Svoid;
      });
}

} // namespace crest

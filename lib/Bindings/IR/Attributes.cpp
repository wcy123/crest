/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Attributes.h

#include "Attributes.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "llvm/Support/raw_ostream.h"
#include "mlir/IR/Attributes.h"

namespace crest {

void registerIRAttributeBindings() {
  // mlir::NamedAttribute::getName (uptr named) -> uptr StringAttr
  // mlir::NamedAttribute::getValue (uptr named) -> uptr Attribute
  //
  // `named` is the address of the NamedAttribute that a verifier of the
  // dialect gets: it lives for the call of the verifier.
  Sregister_symbol(
      "mlir::NamedAttribute::getName", (void*)+[](uint64_t named_ptr) -> ptr {
        if (!named_ptr) {
          return scheme_error("mlir::NamedAttribute::getName",
                              "named attribute pointer is null");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            reinterpret_cast<const mlir::NamedAttribute*>(named_ptr)
                ->getName()
                .getAsOpaquePointer()));
      });
  Sregister_symbol(
      "mlir::NamedAttribute::getValue", (void*)+[](uint64_t named_ptr) -> ptr {
        if (!named_ptr) {
          return scheme_error("mlir::NamedAttribute::getValue",
                              "named attribute pointer is null");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            reinterpret_cast<const mlir::NamedAttribute*>(named_ptr)
                ->getValue()
                .getAsOpaquePointer()));
      });

  // The attribute in its textual form, as MLIR prints it.
  Sregister_symbol(
      "mlir::Attribute::print", (void*)+[](uint64_t attr_ptr) -> ptr {
        if (!attr_ptr) {
          return Sstring("");
        }
        std::string str;
        llvm::raw_string_ostream os(str);
        mlir::Attribute::getFromOpaquePointer(
            reinterpret_cast<const void*>(attr_ptr))
            .print(os);
        return Sstring(str.c_str());
      });
}

} // namespace crest

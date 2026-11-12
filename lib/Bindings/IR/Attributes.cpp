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
  register_binding(
      "mlir::NamedAttribute::getName",
      [](uint64_t named_ptr) -> llvm::Expected<uint64_t> {
        if (!named_ptr) {
          return fail("mlir::NamedAttribute::getName",
                      llvm::Twine("named attribute pointer is null"));
        }
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<const mlir::NamedAttribute*>(named_ptr)
                ->getName()
                .getAsOpaquePointer());
      });
  register_binding(
      "mlir::NamedAttribute::getValue",
      [](uint64_t named_ptr) -> llvm::Expected<uint64_t> {
        if (!named_ptr) {
          return fail("mlir::NamedAttribute::getValue",
                      llvm::Twine("named attribute pointer is null"));
        }
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<const mlir::NamedAttribute*>(named_ptr)
                ->getValue()
                .getAsOpaquePointer());
      });

  // The attribute in its textual form, as MLIR prints it.
  register_binding("mlir::Attribute::print", [](uint64_t attr_ptr) -> ptr {
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

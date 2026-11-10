/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/InliningUtils.h

#include "InliningUtils.h"
#include "../Support/BuilderBinding.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Dialect.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Transforms/InliningUtils.h"
#include "mlir/Transforms/Passes.h"

namespace crest {

void registerTransformsInliningUtilsBindings() {
  // mlir::DialectInlinerInterface::getInterfaceID () -> uptr
  //
  // The address that the TypeID of the interface wraps: the :interfaces clause
  // of a dialect pairs it with the dispatcher, and C++ finds how to install the
  // interface by it (lib/Crest/Dialect.cpp).
  Sregister_symbol(
      "mlir::DialectInlinerInterface::getInterfaceID",
      (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::DialectInlinerInterface::getInterfaceID()
                .getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::createInlinerPass", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            new CrestBox<std::unique_ptr<mlir::Pass>>(
                mlir::createInlinerPass()));
      });
  // DialectInlinerInterface::materializeCallConversion(OpBuilder&, Value, Type,
  // Location) on the inliner interface the dialect registers. (builder dialect
  // input result-type loc) → Operation* uptr, 0 when none
  register_builder_binding(
      "mlir::DialectInlinerInterface::materializeCallConversion",
      [](mlir::OpBuilder& builder, uint64_t dialect_ptr, uint64_t input_ptr,
         uint64_t type_ptr, uint64_t loc_ptr) -> uint64_t {
        auto* dialect = reinterpret_cast<mlir::Dialect*>(dialect_ptr);
        auto* iface =
            dialect
                ? dialect
                      ->getRegisteredInterface<mlir::DialectInlinerInterface>()
                : nullptr;
        if (!iface) {
          scheme_error(
              "mlir::DialectInlinerInterface::materializeCallConversion",
              "the dialect has no DialectInlinerInterface");
        }
        auto input = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(input_ptr));
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        return reinterpret_cast<uint64_t>(
            iface->materializeCallConversion(builder, input, type, loc));
      });
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/DialectRegistry.h

#include "DialectRegistry.h"
#include "../../Crest/Dialect.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/DialectRegistry.h"

namespace crest {

void registerIRDialectRegistryBindings() {
  /// → CrestBox<mlir::DialectRegistry>*
  Sregister_symbol(
      "mlir::DialectRegistry::new", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            new CrestBox<mlir::DialectRegistry>());
      });

  /// registry_ptr: CrestBox<mlir::DialectRegistry>*, dialect_name: string,
  /// module_name: string
  Sregister_symbol(
      "mlir::DialectRegistry::insert",
      (void*)+[](uint64_t registry_ptr, const char* dialect_name,
                 const char* module_name) -> void {
        auto& registry = crest::CrestBox<mlir::DialectRegistry>::inner(
            registry_ptr, "mlir::DialectRegistry::insert");
        auto [type_id, factory] = crest::dialectFactory(
            std::string(dialect_name), std::string(module_name));
        registry.insert(type_id, std::string(dialect_name), factory);
      });
}

} // namespace crest

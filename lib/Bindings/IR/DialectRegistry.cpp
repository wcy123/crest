/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/DialectRegistry.h

#include "DialectRegistry.h"
#include "../../Crest/Dialect.h"
#include "../Support/CrestObject.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/DialectRegistry.h"

namespace crest {

void registerIRDialectRegistryBindings() {
  /// → CrestBox<mlir::DialectRegistry>*
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-DialectRegistry, which frees it after its body. A registry made by
  // calling this directly and never freed leaks.
  Sregister_symbol(
      "mlir::DialectRegistry::new", (void*)+[]() -> ptr {
        return Sunsigned64(
            reinterpret_cast<uint64_t>(new CrestBox<mlir::DialectRegistry>()));
      });

  /// registry_ptr: CrestBox<mlir::DialectRegistry>*, dialect_name: string,
  /// module_name: string
  Sregister_symbol(
      "mlir::DialectRegistry::insert",
      (void*)+[](uint64_t registry_ptr, const char* dialect_name,
                 const char* module_name) -> ptr {
        auto* registry_box =
            crest::CrestBox<mlir::DialectRegistry>::inner(registry_ptr);
        if (!registry_box) {
          return scheme_error(
              "mlir::DialectRegistry::insert",
              "null pointer or not a CrestBox<mlir::DialectRegistry>");
        }
        auto& registry = *registry_box;
        // Copy first: the strings point into the Scheme heap, which the Scheme
        // code that validateSchemeDialect runs may move.
        std::string dialect(dialect_name);
        std::string module(module_name);
        if (auto error = crest::validateSchemeDialect(dialect, module)) {
          return scheme_error("mlir::DialectRegistry::insert",
                              llvm::Twine("Failed to import Scheme library: ") +
                                  module + ": " + *error);
        }
        auto [type_id, factory] = crest::dialectFactory(dialect, module);
        registry.insert(type_id, dialect, factory);
        return Svoid;
      });
}

} // namespace crest

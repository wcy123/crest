/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// CrestOp bridge — lib/Crest/Op.h
//
// Analogous to CrestDialect: stores Scheme callbacks for each
// DynamicOpDefinition hook and bridges them into llvm::unique_function types
// that MLIR expects.

#ifndef CREST_OP_H
#define CREST_OP_H

#include "../Bindings/Support/LockedSchemeObject.h"
#include "mlir/IR/ExtensibleDialect.h"
#include <optional>

namespace crest {

/// Bridges a Scheme-defined op into a mlir::DynamicOpDefinition.
///
/// Each callback slot is optional — absent (std::nullopt) means use MLIR's
/// default behaviour (e.g. generic assembly format, always-success verify).
///
/// Unlike CrestDialect (which uses C++ virtual dispatch), DynamicOpDefinition
/// stores llvm::unique_function — move-only callables. Each LockedSchemeObject
/// is moved directly into its unique_function, keeping the Scheme procedure
/// GC-locked for the lifetime of the op registration.
class CrestOp {
public:
  struct Callbacks {
    std::optional<LockedSchemeObject> verify;                        // 0
    std::optional<LockedSchemeObject> verify_regions;                // 1
    std::optional<LockedSchemeObject> parse;                         // 2
    std::optional<LockedSchemeObject> print;                         // 3
    std::optional<LockedSchemeObject> fold;                          // 4
    std::optional<LockedSchemeObject> get_canonicalization_patterns; // 5
    std::optional<LockedSchemeObject> populate_default_attrs;        // 6
  };

  /// Build a DynamicOpDefinition from the callbacks and register it into
  /// the given dialect. Must be called from inside the dialect's initialize().
  static void registerInto(mlir::ExtensibleDialect* dialect,
                           llvm::StringRef op_name, Callbacks cbs);
};

void registerCrestDynamicOpBindings();

} // namespace crest

#endif // CREST_OP_H

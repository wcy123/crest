/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// CrestOp bridge — lib/Crest/Op.h
//
// Analogous to CrestDialect: stores the entry point of the Scheme
// foreign-callable of each DynamicOpDefinition hook and bridges them into
// llvm::unique_function types that MLIR expects.

#ifndef CREST_OP_H
#define CREST_OP_H

#include <string>
#include <vector>

#include "../Bindings/Support/LockedSchemeObject.h"
#include "mlir/IR/ExtensibleDialect.h"

namespace crest {

/// Bridges a Scheme-defined op into a mlir::DynamicOpDefinition.
///
/// Each callback slot is optional — absent (nullptr) means use MLIR's default
/// behaviour (e.g. generic assembly format, always-success verify).
///
/// The entry points are those of foreign-callables that the dialect's library
/// made once (scheme/crest/dialect/callbacks.sls); they stay valid for the
/// process, so a closure over one is all the unique_function needs. Objects
/// cross as integers. Each callable has the C result type written here: 1 or
/// 0 for a verdict (0 is a failure, also when its Scheme procedure raised an
/// error, which the callable reported as a diagnostic at its Scheme source),
/// void for a hook that answers nothing (an error of its procedure ends the
/// process).
class CrestOp {
public:
  struct Callbacks {
    int (*verify)(uint64_t op) = nullptr;                               // 0
    int (*verify_regions)(uint64_t op) = nullptr;                       // 1
    int (*parse)(uint64_t parser, uint64_t state) = nullptr;            // 2
    void (*print)(uint64_t op, uint64_t printer) = nullptr;             // 3
    int (*fold)(uint64_t op, uint64_t operand_attrs,
                void* folded) = nullptr;                                // 4
    void (*get_canonicalization_patterns)(uint64_t patterns) = nullptr; // 5
    void (*populate_default_attrs)(uint64_t name,
                                   uint64_t attrs) = nullptr;           // 6
    std::vector<std::vector<std::string>> traits;                       // 7
  };

  /// Build a DynamicOpDefinition from the callbacks and register it into
  /// the given dialect. Must be called from inside the dialect's initialize().
  /// `interfaces` is the list of (TypeID . dispatcher) pairs of the op's
  /// :interfaces entries, locked by the caller; it is not kept after the call.
  /// Answers the text of the error when the op cannot be registered, and ""
  /// when it was. It does not raise: the caller answers it to Scheme after it
  /// has destroyed its objects and unlocked `interfaces` (see Result.h).
  static std::string registerInto(mlir::ExtensibleDialect* dialect,
                                  llvm::StringRef op_name, Callbacks cbs,
                                  const LockedSchemeObject& interfaces);
};

void registerCrestDynamicOpBindings();

} // namespace crest

#endif // CREST_OP_H

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// CrestDialect bridge — lib/Crest/Dialect.h

#ifndef CREST_DIALECT_H
#define CREST_DIALECT_H

#include "../Bindings/Support/LockedSchemeObject.h"
#include "../Interpreter/ChezSchemeInterpreter.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/Support/TypeID.h"

#include <memory>
#include <optional>
#include <string>

namespace crest {

/// C++ bridge that implements every mlir::Dialect virtual method by
/// calling the entry point of a Chez Scheme foreign-callable that the dialect's
/// library made once (scheme/crest/dialect/callbacks.sls). A missing callback
/// (nullptr) falls through to ExtensibleDialect's default.
///
/// ## Design rationale — TypeID management
///
/// Every MLIR dialect needs a stable TypeID for the lifetime of the
/// MLIRContext. Static C++ dialects get theirs from a static storage variable
/// via MLIR_DECLARE_EXPLICIT_TYPE_ID (linker-unique, zero overhead). That
/// mechanism requires a C++ class per dialect — unavailable for runtime
/// Scheme dialects.
///
/// Two dynamic alternatives exist in MLIR:
///   (a) mlir::SelfOwningTypeID — storage lives inside the Dialect object;
///       TypeID == &storage.  Simple, but the ID is not known until the
///       object is constructed, which prevents registry-based lazy loading.
///   (b) mlir::TypeIDAllocator — pre-allocates stable storage independently
///       of the Dialect object; ID can be recorded in the DialectRegistry
///       before any Dialect is instantiated.
///
/// CREST uses (b) so that Scheme-defined dialects can be registered in the
/// MLIRContext's DialectRegistry via crest::register-dialect! and then loaded
/// lazily by name through ctx->getOrLoadDialect("toy"). This is essential for
/// dependent dialect loading: if "toy-2" declares "toy-1" as a dependency,
/// MLIR calls getOrLoadDialect("toy-1") during initialization — which only
/// works when "toy-1" has a factory in the registry.
///
/// ## Why not mlir::DynamicDialect / insertDynamic?
///
/// DialectRegistry::insertDynamic creates a mlir::DynamicDialect (MLIR's own
/// runtime class). Its population callback can register dynamic ops/types/attrs
/// but CANNOT override the dialect's virtual methods (parseAttribute,
/// printType, etc.). CrestDialect must override those methods to dispatch into
/// Scheme, so we cannot use insertDynamic and instead use the lower-level
/// DialectRegistry::insert(TypeID, name, factory).
///
/// ## Why Python MLIR bindings do not use this approach
///
/// Python bindings define dialects through ODS / mlir-tblgen, producing a
/// statically compiled C++ class per dialect even when the surface API is
/// Python. Truly dynamic Python-defined dialects (no backing C++ class) are
/// not a supported use-case, so the registry factory mechanism was never
/// needed. See llvm-project issue #74245, which is still an open feature
/// request for even basic per-dialect registration from pure Python.
class CrestDialect : public mlir::ExtensibleDialect {
public:
  /// One entry point per virtual method; nullptr means absent (fall through to
  /// the ExtensibleDialect default). Pointers and the dialect itself cross as
  /// integers; the Scheme side adapts the answers (a failed parse is 0). Each
  /// callable has the C result type written here: void for the hooks that
  /// answer nothing (an error of its Scheme procedure ends the process), a
  /// pointer or 0 for a parse or a builder, 1 or 0 for a verdict. An error of a
  /// procedure that has a result is a diagnostic at its Scheme source, and the
  /// callable answers 0 (scheme/crest/callback.sls).
  struct Callbacks {
    void (*initialize)(uint64_t dialect) = nullptr;
    void (*get_dependent_dialects)(uint64_t dialect) = nullptr;
    uint64_t (*parse_attribute)(uint64_t parser, uint64_t type) = nullptr;
    void (*print_attribute)(uint64_t attr, uint64_t printer) = nullptr;
    uint64_t (*parse_type)(uint64_t parser) = nullptr;
    void (*print_type)(uint64_t type, uint64_t printer) = nullptr;
    uint64_t (*materialize_constant)(uint64_t builder, uint64_t value,
                                     uint64_t type, uint64_t loc) = nullptr;
    void (*get_canonicalization_patterns)(uint64_t patterns) = nullptr;
    int (*verify_op_attr)(uint64_t op, uint64_t attr) = nullptr;
    int (*verify_region_arg_attr)(uint64_t op, uint32_t region_index,
                                  uint32_t arg_index, uint64_t attr) = nullptr;
    int (*verify_region_result_attr)(uint64_t op, uint32_t region_index,
                                     uint32_t result_index,
                                     uint64_t attr) = nullptr;
  };

  /// Constructor for use with Crest::dialectFactory /
  /// --crest-scheme-dialect. Imports module_name via the Chez Scheme
  /// interpreter, retrieves callbacks via the vector that define-dialect binds
  /// to the dialect's name, and initializes ops. Holds a
  /// shared_ptr to the interpreter to keep the Scheme runtime alive for the
  /// dialect's lifetime.
  CrestDialect(mlir::TypeID id, const std::string& module_name,
               const std::string& dialect_name, mlir::MLIRContext* ctx);

  /// Allocates a stable TypeID from the process-global TypeIDAllocator.
  /// Hides the allocator implementation detail from callers.
  static mlir::TypeID allocateTypeId();

  static bool classof(const mlir::Dialect* d);

  // --- mlir::Dialect virtual interface ---
  /// `interfaces`: the list of (TypeID . dispatcher) pairs of the :interfaces
  /// clause of the dialect, locked by the caller.
  void initialize(const LockedSchemeObject& interfaces);

  mlir::Attribute parseAttribute(mlir::DialectAsmParser& parser,
                                 mlir::Type type) const override;
  void printAttribute(mlir::Attribute attr,
                      mlir::DialectAsmPrinter& os) const override;

  mlir::Type parseType(mlir::DialectAsmParser& parser) const override;
  void printType(mlir::Type type, mlir::DialectAsmPrinter& os) const override;

  mlir::Operation* materializeConstant(mlir::OpBuilder& builder,
                                       mlir::Attribute value, mlir::Type type,
                                       mlir::Location loc) override;

  void
  getCanonicalizationPatterns(mlir::RewritePatternSet& results) const override;

  mlir::LogicalResult
  verifyOperationAttribute(mlir::Operation* op,
                           mlir::NamedAttribute attr) override;
  mlir::LogicalResult
  verifyRegionArgAttribute(mlir::Operation* op, unsigned regionIndex,
                           unsigned argIndex,
                           mlir::NamedAttribute attr) override;
  mlir::LogicalResult
  verifyRegionResultAttribute(mlir::Operation* op, unsigned regionIndex,
                              unsigned resultIndex,
                              mlir::NamedAttribute attr) override;

private:
  Callbacks cbs_;
  // Holds the interpreter alive for the dialect's lifetime (the callables
  // behind the entry points in cbs_ live in its heap). The interpreter is a
  // strong singleton so this is mainly for clarity / correctness under future
  // refactoring.
  std::shared_ptr<ChezSchemeInterpreter> interp_;
};

void registerIRExtensibleDialectBindings();

/// Build a (TypeID, factory) pair for a Scheme-defined dialect.
///
/// @param dialect_name  The MLIR dialect namespace, e.g. "toy".
/// @param module_name   The Scheme library path in slash-separated form,
///                      e.g. "toy/ch4/toy" (equivalent to the R6RS library
///                      name (toy ch4 toy), the same format accepted by
///                      ChezSchemeInterpreter::importLibrary).
///
/// Insert the result into a DialectRegistry before creating any MLIRContext
/// to avoid the UnregisteredOpModel use-after-free described in
/// tech-note.md ("Dialect Registration Must Happen Before Parsing").
///
/// Example:
/// @code
///   mlir::DialectRegistry registry;
///   auto [type_id, factory] = crest::dialectFactory("toy", "toy/ch4/toy");
///   registry.insert(type_id, "toy", factory);
///   mlir::MLIRContext ctx(registry);
/// @endcode
std::pair<mlir::TypeID, mlir::DialectAllocatorFunction>
dialectFactory(std::string dialect_name, std::string module_name);

/// Imports the library `module_name` and checks it defines `dialect_name`
/// (see ChezSchemeInterpreter::importDialectLibrary). Returns why it does not,
/// or std::nullopt. The CrestDialect constructor cannot fail, so every place
/// that registers a dialectFactory calls this first and reports the failure
/// its own way.
std::optional<std::string>
validateSchemeDialect(const std::string& dialect_name,
                      const std::string& module_name);

} // namespace crest

#endif // CREST_DIALECT_H

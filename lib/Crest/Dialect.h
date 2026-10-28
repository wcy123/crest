/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// CrestDialect bridge — lib/Crest/Dialect.h

#ifndef CREST_DIALECT_H
#define CREST_DIALECT_H

#include "../Bindings/Support/LockedSchemeObject.h"
#include "Interface.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/Support/TypeID.h"

namespace crest {

/// C++ bridge that implements every mlir::Dialect virtual method by
/// delegating to a locked Chez Scheme callback. A missing callback
/// (std::nullopt) falls through to ExtensibleDialect's default.
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
  /// One locked callback per virtual method; Sfalse means absent (fall through
  /// to ExtensibleDialect default).
  struct Callbacks {
    LockedSchemeObject initialize;
    LockedSchemeObject get_dependent_dialects;
    LockedSchemeObject parse_attribute;
    LockedSchemeObject print_attribute;
    LockedSchemeObject parse_type;
    LockedSchemeObject print_type;
    LockedSchemeObject materialize_constant;
    LockedSchemeObject get_canonicalization_patterns;
    LockedSchemeObject verify_op_attr;
    LockedSchemeObject verify_region_arg_attr;
    LockedSchemeObject verify_region_result_attr;
    void* (*register_op_interfaces)(mlir::TypeID,
                                    const std::string&) = &LookupInterfaceForOp;
  };

  /// id must be pre-allocated from the global TypeIDAllocator in
  /// registerIRExtensibleDialectBindings and passed consistently to both the
  /// DialectRegistry factory and this constructor so the TypeID is identical
  /// everywhere MLIR uses it for lookup and isa<> checks.
  CrestDialect(llvm::StringRef name, mlir::MLIRContext* ctx, mlir::TypeID id,
               Callbacks cbs);

  static bool classof(const mlir::Dialect* d);

  // --- mlir::Dialect virtual interface ---
  void initialize();

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

  void* getRegisteredInterfaceForOp(mlir::TypeID interfaceID,
                                    mlir::OperationName opName) override;

private:
  Callbacks cbs_;
};

void registerIRExtensibleDialectBindings();

/// Load a dialect into the context by namespace string, safe to call from
/// inside a running pass (works around the multiThreadedExecutionContext
/// assertion by bracketing with exit/enterMultiThreadedExecution).
/// No-ops if the dialect is already loaded.
void loadDialectByName(mlir::MLIRContext* ctx, llvm::StringRef ns);

} // namespace crest

#endif // CREST_DIALECT_H

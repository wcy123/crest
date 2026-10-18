/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Mirrors mlir/IR/ExtensibleDialect.h

#ifndef CREST_BINDINGS_IR_EXTENSIBLE_DIALECT_H
#define CREST_BINDINGS_IR_EXTENSIBLE_DIALECT_H

#include "../Support/LockedSchemeObject.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/Support/TypeID.h"
#include <optional>

namespace crest {

/// C++ bridge that implements every mlir::Dialect virtual method by
/// delegating to a locked Chez Scheme callback.  A missing callback
/// (std::nullopt) falls through to ExtensibleDialect's default.
///
/// Mirrors the same SelfOwningTypeID + ExtensibleDialect pattern that
/// mlir::DynamicDialect uses, so each instance gets a unique TypeID
/// without compile-time codegen.
class CrestDialect : public mlir::SelfOwningTypeID,
                     public mlir::ExtensibleDialect {
public:
  /// One optional locked callback per virtual method.
  struct Callbacks {
    std::optional<LockedSchemeObject> initialize;
    std::optional<LockedSchemeObject> get_dependent_dialects;
    std::optional<LockedSchemeObject> parse_attribute;
    std::optional<LockedSchemeObject> print_attribute;
    std::optional<LockedSchemeObject> parse_type;
    std::optional<LockedSchemeObject> print_type;
    std::optional<LockedSchemeObject> materialize_constant;
    std::optional<LockedSchemeObject> get_canonicalization_patterns;
    std::optional<LockedSchemeObject> verify_op_attr;
    std::optional<LockedSchemeObject> verify_region_arg_attr;
    std::optional<LockedSchemeObject> verify_region_result_attr;
    std::optional<LockedSchemeObject> get_registered_interface_for_op;
  };

  CrestDialect(llvm::StringRef name, mlir::MLIRContext* ctx, Callbacks cbs);

  mlir::TypeID getTypeID() const;

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

} // namespace crest

#endif // CREST_BINDINGS_IR_EXTENSIBLE_DIALECT_H

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Mirrors mlir/IR/ExtensibleDialect.h

#include "ExtensibleDialect.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectImplementation.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Read a Scheme uptr back as a typed pointer.
template <typename T> static T* ptr_from_scheme(ptr val) {
  return reinterpret_cast<T*>(static_cast<uint64_t>(Sinteger64_value(val)));
}

// ---------------------------------------------------------------------------
// CrestDialect — constructor, classof, getTypeID
// ---------------------------------------------------------------------------

CrestDialect::CrestDialect(llvm::StringRef name, mlir::MLIRContext* ctx,
                           Callbacks cbs)
    : mlir::ExtensibleDialect(name, ctx, mlir::SelfOwningTypeID::getTypeID()),
      cbs_(std::move(cbs)) {}

mlir::TypeID CrestDialect::getTypeID() const {
  return mlir::SelfOwningTypeID::getTypeID();
}

bool CrestDialect::classof(const mlir::Dialect* d) {
  return mlir::isa<mlir::ExtensibleDialect>(d);
}

// ---------------------------------------------------------------------------
// Virtual method bridges
// Each calls the Scheme callback if present, else falls through to
// ExtensibleDialect's default.
// ---------------------------------------------------------------------------

void CrestDialect::initialize() {
  // Load dependent dialects first — callback returns a Scheme list of
  // namespace strings e.g. '("arith" "func").
  // get_dependent_dialects returns a Scheme list of uptr (const char*)
  // namespace strings — each element is a pointer to a null-terminated C
  // string.
  if (cbs_.get_dependent_dialects) {
    ptr deps = scheme_call(cbs_.get_dependent_dialects->get());
    for (; deps != Snil; deps = Scdr(deps)) {
      auto* ns = reinterpret_cast<const char*>(
          static_cast<uint64_t>(Sinteger64_value(Scar(deps))));
      getContext()->getOrLoadDialect(llvm::StringRef(ns));
    }
  }
  if (cbs_.initialize) {
    scheme_call(cbs_.initialize->get(), this);
  }
}

mlir::Attribute CrestDialect::parseAttribute(mlir::DialectAsmParser& parser,
                                             mlir::Type type) const {
  if (cbs_.parse_attribute) {
    return mlir::Attribute::getFromOpaquePointer(
        ptr_from_scheme<void>(scheme_call(cbs_.parse_attribute->get(), &parser,
                                          type.getAsOpaquePointer())));
  }
  return mlir::ExtensibleDialect::parseAttribute(parser, type);
}

void CrestDialect::printAttribute(mlir::Attribute attr,
                                  mlir::DialectAsmPrinter& os) const {
  if (cbs_.print_attribute) {
    scheme_call(cbs_.print_attribute->get(), attr.getAsOpaquePointer(), &os);
  } else {
    mlir::ExtensibleDialect::printAttribute(attr, os);
  }
}

mlir::Type CrestDialect::parseType(mlir::DialectAsmParser& parser) const {
  if (cbs_.parse_type) {
    return mlir::Type::getFromOpaquePointer(
        ptr_from_scheme<void>(scheme_call(cbs_.parse_type->get(), &parser)));
  }
  return mlir::ExtensibleDialect::parseType(parser);
}

void CrestDialect::printType(mlir::Type type,
                             mlir::DialectAsmPrinter& os) const {
  if (cbs_.print_type) {
    scheme_call(cbs_.print_type->get(), type.getAsOpaquePointer(), &os);
  } else {
    mlir::ExtensibleDialect::printType(type, os);
  }
}

mlir::Operation* CrestDialect::materializeConstant(mlir::OpBuilder& builder,
                                                   mlir::Attribute value,
                                                   mlir::Type type,
                                                   mlir::Location loc) {
  if (cbs_.materialize_constant) {
    return ptr_from_scheme<mlir::Operation>(scheme_call(
        cbs_.materialize_constant->get(), &builder, value.getAsOpaquePointer(),
        type.getAsOpaquePointer(), loc.getAsOpaquePointer()));
  }
  return mlir::ExtensibleDialect::materializeConstant(builder, value, type,
                                                      loc);
}

void CrestDialect::getCanonicalizationPatterns(
    mlir::RewritePatternSet& results) const {
  if (cbs_.get_canonicalization_patterns) {
    scheme_call(cbs_.get_canonicalization_patterns->get(), &results);
  } else {
    mlir::ExtensibleDialect::getCanonicalizationPatterns(results);
  }
}

mlir::LogicalResult
CrestDialect::verifyOperationAttribute(mlir::Operation* op,
                                       mlir::NamedAttribute attr) {
  if (cbs_.verify_op_attr) {
    return Sboolean_value(scheme_call(cbs_.verify_op_attr->get(), op, &attr))
               ? mlir::success()
               : mlir::failure();
  }
  return mlir::ExtensibleDialect::verifyOperationAttribute(op, attr);
}

mlir::LogicalResult
CrestDialect::verifyRegionArgAttribute(mlir::Operation* op,
                                       unsigned regionIndex, unsigned argIndex,
                                       mlir::NamedAttribute attr) {
  if (cbs_.verify_region_arg_attr) {
    return Sboolean_value(scheme_call(cbs_.verify_region_arg_attr->get(), op,
                                      regionIndex, argIndex, &attr))
               ? mlir::success()
               : mlir::failure();
  }
  return mlir::ExtensibleDialect::verifyRegionArgAttribute(op, regionIndex,
                                                           argIndex, attr);
}

mlir::LogicalResult CrestDialect::verifyRegionResultAttribute(
    mlir::Operation* op, unsigned regionIndex, unsigned resultIndex,
    mlir::NamedAttribute attr) {
  if (cbs_.verify_region_result_attr) {
    return Sboolean_value(scheme_call(cbs_.verify_region_result_attr->get(), op,
                                      regionIndex, resultIndex, &attr))
               ? mlir::success()
               : mlir::failure();
  }
  return mlir::ExtensibleDialect::verifyRegionResultAttribute(
      op, regionIndex, resultIndex, attr);
}

void* CrestDialect::getRegisteredInterfaceForOp(mlir::TypeID interfaceID,
                                                mlir::OperationName opName) {
  if (cbs_.get_registered_interface_for_op) {
    return ptr_from_scheme<void>(scheme_call(
        cbs_.get_registered_interface_for_op->get(), &interfaceID, &opName));
  }
  return mlir::ExtensibleDialect::getRegisteredInterfaceForOp(interfaceID,
                                                              opName);
}

// ---------------------------------------------------------------------------
// Sregister_symbol bindings
// ---------------------------------------------------------------------------

void registerIRExtensibleDialectBindings() {
  // crest::load-dialect!
  // (uptr ctx) (uptr name-cstr) (uptr scheme-vector-of-12-callbacks) → uptr
  // Callbacks vector slots (Sfalse = use default):
  //   0 initialize                       6 materialize-constant
  //   1 get-dependent-dialects           7 get-canonicalization-patterns
  //   2 parse-attribute                  8 verify-op-attr
  //   3 print-attribute                  9 verify-region-arg-attr
  //   4 parse-type                      10 verify-region-result-attr
  //   5 print-type                      11 get-registered-interface-for-op
  Sregister_symbol(
      "crest::load-dialect!",
      (void*)+[](uint64_t ctx_ptr, uint64_t name_ptr,
                 uint64_t cbs_ptr) -> uint64_t {
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        llvm::StringRef name(reinterpret_cast<const char*>(name_ptr));

        if (auto* existing = ctx->getLoadedDialect(name)) {
          return reinterpret_cast<uint64_t>(existing);
        }

        auto make_cb = [](ptr slot) -> std::optional<LockedSchemeObject> {
          if (slot == Sfalse) {
            return std::nullopt;
          }
          return LockedSchemeObject(slot);
        };
        ptr v = reinterpret_cast<ptr>(cbs_ptr);
        CrestDialect::Callbacks cbs;
        cbs.initialize = make_cb(Svector_ref(v, 0));
        cbs.get_dependent_dialects = make_cb(Svector_ref(v, 1));
        cbs.parse_attribute = make_cb(Svector_ref(v, 2));
        cbs.print_attribute = make_cb(Svector_ref(v, 3));
        cbs.parse_type = make_cb(Svector_ref(v, 4));
        cbs.print_type = make_cb(Svector_ref(v, 5));
        cbs.materialize_constant = make_cb(Svector_ref(v, 6));
        cbs.get_canonicalization_patterns = make_cb(Svector_ref(v, 7));
        cbs.verify_op_attr = make_cb(Svector_ref(v, 8));
        cbs.verify_region_arg_attr = make_cb(Svector_ref(v, 9));
        cbs.verify_region_result_attr = make_cb(Svector_ref(v, 10));
        cbs.get_registered_interface_for_op = make_cb(Svector_ref(v, 11));

        auto dialect =
            std::make_unique<CrestDialect>(name, ctx, std::move(cbs));
        mlir::TypeID id = dialect->getTypeID();
        mlir::Dialect* registered = ctx->getOrLoadDialect(
            name, id,
            [d = std::move(dialect)]() mutable
            -> std::unique_ptr<mlir::Dialect> { return std::move(d); });
        return reinterpret_cast<uint64_t>(registered);
      });
}

} // namespace crest

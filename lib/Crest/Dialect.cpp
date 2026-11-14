/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// CrestDialect bridge — lib/Crest/Dialect.cpp

#include "Dialect.h"
#include "../Bindings/Support/CrestObject.h"
#include "../Bindings/Support/Result.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "CurrentContext.h"
#include "InlinerInterface.h"
#include "Interface.h"
#include "llvm/ADT/DenseMap.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectImplementation.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Support/TypeID.h"
#include "mlir/Transforms/InliningUtils.h"
#include <memory>
#include <string>
#include <unordered_map>

namespace crest {

// ---------------------------------------------------------------------------
// Scheme dialects have no C++ class, so MLIR_DECLARE_EXPLICIT_TYPE_ID is
// unavailable (it requires a static variable per class, established at link
// time). TypeIDAllocator lets us mint a stable TypeID before the Dialect
// object exists — necessary to register a factory in DialectRegistry before
// any instance is created.
//
// Process-lifetime: TypeID storage must outlive every Dialect that uses it.
// Dialects live as long as their MLIRContext, which in CREST lives as long
// as the process, so a static allocator is correct.
//
// Not thread-safe: Chez Scheme is single-threaded, so concurrent calls to
// crest::register-dialect! cannot occur. Add a mutex if that changes.
// ---------------------------------------------------------------------------
static mlir::TypeIDAllocator g_crest_type_id_allocator;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

mlir::TypeID CrestDialect::allocateTypeId() {
  return g_crest_type_id_allocator.allocate();
}

// ---------------------------------------------------------------------------
// Virtual method bridges
// ---------------------------------------------------------------------------

namespace {
// The verdict of a verifier of Scheme: its callable answers 1 (valid) or 0
// (invalid, or its procedure raised an error, which the callable reported).
mlir::LogicalResult verifyResult(int answer) {
  return answer != 0 ? mlir::success() : mlir::failure();
}
} // namespace

namespace {
// How an interface whose methods come from Scheme is installed in a dialect:
// from its dispatcher of C, locked by the caller for the call. Keyed by the
// TypeID of the interface, like the table of the ops in lib/Crest/Op.cpp.
using AttachDialectInterfaceFn = void (*)(CrestDialect& dialect,
                                          const LockedSchemeObject& dispatcher);

const llvm::DenseMap<mlir::TypeID, AttachDialectInterfaceFn>&
getAttachDialectInterfaceFns() {
  static const llvm::DenseMap<mlir::TypeID, AttachDialectInterfaceFn> fns = {
      {mlir::DialectInlinerInterface::getInterfaceID(),
       attachDialectInlinerInterface},
  };
  return fns;
}
} // namespace

CrestDialect::~CrestDialect() { clearCurrentContext(*interp_, getContext()); }

void CrestDialect::initialize(const LockedSchemeObject& interfaces) {
  // Load dependent dialects first. The callback gives each name of a dialect
  // namespace (e.g. "arith") to crest::CrestDialect::loadDependentDialect,
  // which calls getOrLoadDialect(name); MLIR finds the factory in the
  // DialectRegistry and instantiates it if not already loaded. That works for
  // built-in MLIR dialects the host registered (registry.insert<T>(),
  // registerAllDialects()) and for other Scheme dialects registered by name
  // (--crest-scheme-dialect).
  mlir::Location here = mlir::UnknownLoc::get(getContext());
  // The callables of this dialect report their errors in this context.
  setCurrentContext(*interp_, getContext());
  if (cbs_.get_dependent_dialects) {
    cbs_.get_dependent_dialects(reinterpret_cast<uint64_t>(this));
  }
  std::string attachError =
      attachInterfaces(*this, interfaces, getAttachDialectInterfaceFns());
  if (!attachError.empty()) {
    // This runs inside MLIR's construction of the dialect, so there is no way
    // to return the error to MLIR: it is a diagnostic. A mistake in the
    // define-dialect form.
    mlir::emitError(here) << "crest::CrestDialect: " << attachError;
    return;
  }
  if (cbs_.initialize) {
    cbs_.initialize(reinterpret_cast<uint64_t>(this));
  }
}

mlir::Attribute CrestDialect::parseAttribute(mlir::DialectAsmParser& parser,
                                             mlir::Type type) const {
  if (cbs_.parse_attribute) {
    uint64_t answer = cbs_.parse_attribute(
        reinterpret_cast<uint64_t>(&parser),
        reinterpret_cast<uint64_t>(type.getAsOpaquePointer()));
    return mlir::Attribute::getFromOpaquePointer(
        reinterpret_cast<const void*>(answer));
  }
  return mlir::ExtensibleDialect::parseAttribute(parser, type);
}

void CrestDialect::printAttribute(mlir::Attribute attr,
                                  mlir::DialectAsmPrinter& os) const {
  if (cbs_.print_attribute) {
    cbs_.print_attribute(reinterpret_cast<uint64_t>(attr.getAsOpaquePointer()),
                         reinterpret_cast<uint64_t>(&os));
  } else {
    mlir::ExtensibleDialect::printAttribute(attr, os);
  }
}

mlir::Type CrestDialect::parseType(mlir::DialectAsmParser& parser) const {
  if (cbs_.parse_type) {
    uint64_t answer = cbs_.parse_type(reinterpret_cast<uint64_t>(&parser));
    return mlir::Type::getFromOpaquePointer(
        reinterpret_cast<const void*>(answer));
  }
  // The dialect's own types (define-type): the keyword names one of them.
  llvm::StringRef keyword;
  if (mlir::failed(parser.parseKeyword(&keyword))) {
    return mlir::Type();
  }
  mlir::Type result;
  mlir::OptionalParseResult parsed =
      parseOptionalDynamicType(keyword, parser, result);
  if (parsed.has_value() && mlir::succeeded(*parsed)) {
    return result;
  }
  if (!parsed.has_value()) {
    parser.emitError(parser.getNameLoc(), "unknown type '" + keyword +
                                              "' in dialect '" +
                                              getNamespace() + "'");
  }
  return mlir::Type();
}

void CrestDialect::printType(mlir::Type type,
                             mlir::DialectAsmPrinter& os) const {
  if (cbs_.print_type) {
    cbs_.print_type(reinterpret_cast<uint64_t>(type.getAsOpaquePointer()),
                    reinterpret_cast<uint64_t>(&os));
  } else if (mlir::failed(printIfDynamicType(type, os))) {
    mlir::ExtensibleDialect::printType(type, os);
  }
}

mlir::Operation* CrestDialect::materializeConstant(mlir::OpBuilder& builder,
                                                   mlir::Attribute value,
                                                   mlir::Type type,
                                                   mlir::Location loc) {
  if (cbs_.materialize_constant) {
    // Scheme sees the builder as a borrowed shell that lives for this call.
    crest::CrestBox<mlir::OpBuilder*> builder_shell(&builder);
    uint64_t answer = cbs_.materialize_constant(
        reinterpret_cast<uint64_t>(&builder_shell),
        reinterpret_cast<uint64_t>(value.getAsOpaquePointer()),
        reinterpret_cast<uint64_t>(type.getAsOpaquePointer()),
        reinterpret_cast<uint64_t>(loc.getAsOpaquePointer()));
    return reinterpret_cast<mlir::Operation*>(answer);
  }
  return mlir::ExtensibleDialect::materializeConstant(builder, value, type,
                                                      loc);
}

void CrestDialect::getCanonicalizationPatterns(
    mlir::RewritePatternSet& results) const {
  if (cbs_.get_canonicalization_patterns) {
    // Scheme sees the set as a borrowed shell that lives for this call, as for
    // the patterns of an op.
    crest::CrestBox<mlir::RewritePatternSet*> shell(&results);
    cbs_.get_canonicalization_patterns(reinterpret_cast<uint64_t>(&shell));
  } else {
    mlir::ExtensibleDialect::getCanonicalizationPatterns(results);
  }
}

mlir::LogicalResult
CrestDialect::verifyOperationAttribute(mlir::Operation* op,
                                       mlir::NamedAttribute attr) {
  if (cbs_.verify_op_attr) {
    return verifyResult(cbs_.verify_op_attr(reinterpret_cast<uint64_t>(op),
                                            reinterpret_cast<uint64_t>(&attr)));
  }
  return mlir::ExtensibleDialect::verifyOperationAttribute(op, attr);
}

mlir::LogicalResult
CrestDialect::verifyRegionArgAttribute(mlir::Operation* op,
                                       unsigned regionIndex, unsigned argIndex,
                                       mlir::NamedAttribute attr) {
  if (cbs_.verify_region_arg_attr) {
    return verifyResult(cbs_.verify_region_arg_attr(
        reinterpret_cast<uint64_t>(op), regionIndex, argIndex,
        reinterpret_cast<uint64_t>(&attr)));
  }
  return mlir::ExtensibleDialect::verifyRegionArgAttribute(op, regionIndex,
                                                           argIndex, attr);
}

mlir::LogicalResult CrestDialect::verifyRegionResultAttribute(
    mlir::Operation* op, unsigned regionIndex, unsigned resultIndex,
    mlir::NamedAttribute attr) {
  if (cbs_.verify_region_result_attr) {
    return verifyResult(cbs_.verify_region_result_attr(
        reinterpret_cast<uint64_t>(op), regionIndex, resultIndex,
        reinterpret_cast<uint64_t>(&attr)));
  }
  return mlir::ExtensibleDialect::verifyRegionResultAttribute(
      op, regionIndex, resultIndex, attr);
}

// ---------------------------------------------------------------------------
// Helpers for Sregister_symbol bindings
// ---------------------------------------------------------------------------

// The callbacks vector that define-dialect binds to the dialect's name: one
// entry point per slot, 0 for a slot the dialect leaves to the default.
static CrestDialect::Callbacks unpack_callbacks(ptr v) {
  auto entry = [&](int slot) -> uint64_t {
    ptr value = Svector_ref(v, slot);
    if (!Sfixnump(value) && !Sbignump(value)) {
      llvm::report_fatal_error("crest::CrestDialect: callback slot must be the "
                               "entry point of a callable or 0",
                               /*gen_crash_diag=*/false);
    }
    return static_cast<uint64_t>(Sinteger64_value(value));
  };
  CrestDialect::Callbacks cbs;
  cbs.initialize = reinterpret_cast<decltype(cbs.initialize)>(entry(0));
  cbs.get_dependent_dialects =
      reinterpret_cast<decltype(cbs.get_dependent_dialects)>(entry(1));
  cbs.parse_attribute =
      reinterpret_cast<decltype(cbs.parse_attribute)>(entry(2));
  cbs.print_attribute =
      reinterpret_cast<decltype(cbs.print_attribute)>(entry(3));
  cbs.parse_type = reinterpret_cast<decltype(cbs.parse_type)>(entry(4));
  cbs.print_type = reinterpret_cast<decltype(cbs.print_type)>(entry(5));
  cbs.materialize_constant =
      reinterpret_cast<decltype(cbs.materialize_constant)>(entry(6));
  cbs.get_canonicalization_patterns =
      reinterpret_cast<decltype(cbs.get_canonicalization_patterns)>(entry(7));
  cbs.verify_op_attr = reinterpret_cast<decltype(cbs.verify_op_attr)>(entry(8));
  cbs.verify_region_arg_attr =
      reinterpret_cast<decltype(cbs.verify_region_arg_attr)>(entry(9));
  cbs.verify_region_result_attr =
      reinterpret_cast<decltype(cbs.verify_region_result_attr)>(entry(10));
  return cbs;
}

// ---------------------------------------------------------------------------
// Sregister_symbol bindings
// ---------------------------------------------------------------------------

void registerIRExtensibleDialectBindings() {
  // crest::CrestDialect::loadDependentDialect (uptr dialect) (string name) →
  // void
  //
  // The callback of :get-dependent-dialects gives it each name;
  // getOrLoadDialect finds the factory in the DialectRegistry and loads the
  // dialect first.
  Sregister_symbol(
      "crest::CrestDialect::loadDependentDialect",
      (void*)+[](uint64_t dialect_ptr, const char* name) -> ptr {
        auto* dialect = reinterpret_cast<CrestDialect*>(dialect_ptr);
        if (!dialect->getContext()->getOrLoadDialect(llvm::StringRef(name))) {
          return scheme_error("crest::CrestDialect::loadDependentDialect",
                              llvm::Twine("dialect '") + name +
                                  "' is not in the registry");
        }
        return Svoid;
      });

  // crest::load-scheme-dialect! (uptr ctx) (string dialect-name) (string
  // module-name) → void Loads a Scheme-defined dialect into an existing
  // MLIRContext by delegating to dialectFactory. Safe to call when
  // multiThreadedExecutionContext == 0 (e.g. standalone tools, toyc.sls).
  // Replaces the old crest::register-dialect!.
  Sregister_symbol(
      "crest::load-scheme-dialect!",
      (void*)+[](uint64_t ctx_ptr, const char* dialect_name,
                 const char* module_name) -> ptr {
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("crest::load-scheme-dialect!",
                              "null MLIRContext pointer");
        }
        // Copy first: the strings point into the Scheme heap, which the Scheme
        // code that validateSchemeDialect runs may move.
        std::string dialect(dialect_name);
        std::string module(module_name);
        if (auto error = validateSchemeDialect(dialect, module)) {
          return scheme_error("crest::load-scheme-dialect!",
                              llvm::Twine("Failed to import Scheme library: ") +
                                  module + ": " + *error);
        }
        auto [type_id, factory] = dialectFactory(dialect, module);
        factory(ctx);
        return Svoid;
      });
}

// ---------------------------------------------------------------------------
// New 4-arg constructor and dialectFactory — placed after unpack_callbacks
// ---------------------------------------------------------------------------

CrestDialect::CrestDialect(mlir::TypeID id, const std::string& module_name,
                           const std::string& dialect_name,
                           mlir::MLIRContext* ctx)
    // USE-AFTER-FREE WARNING: MLIR keeps the name that it is given as a
    // pointer, not a copy, and reads it for as long as the context lives (the
    // table of loaded dialects, the sort in getLoadedDialects, every printed
    // `!name.type`). dialect_name belongs to the factory, which is destroyed
    // when the call that loads the dialect returns. The context interns the
    // name: it lives as long as the context does.
    : mlir::ExtensibleDialect(
          mlir::StringAttr::get(ctx, dialect_name).getValue(), ctx, id),
      interp_(ChezSchemeInterpreter::instance(
          SchemeLogLevel::Warning, crest::registerMlirForeignFunctions)) {
  if (auto importError = interp_->importLibrary(module_name)) {
    llvm::report_fatal_error(
        llvm::Twine("CrestDialect: failed to import Scheme library '") +
        module_name + "' for dialect '" + dialect_name + "': " + *importError);
  }
  // The dialect name (e.g. "testd") is bound to the callbacks vector by
  // define-dialect using the call-site identifier, so it has the same scope
  // as the user's (export testd). Stop_level_value finds it after import.
  ptr cbs_vec = Stop_level_value(Sstring_to_symbol(dialect_name.c_str()));
  if (!Svectorp(cbs_vec) || Svector_length(cbs_vec) != 12) {
    // validateSchemeDialect reports this before a factory is registered; this
    // is the backstop for a caller that skipped it.
    llvm::report_fatal_error(
        llvm::Twine("CrestDialect: '") + dialect_name +
        "' of Scheme library '" + module_name +
        "' is not the callbacks vector define-dialect makes");
  }
  // The list of the dialect's interfaces, slot 11, is locked before anything
  // that can call Scheme: the garbage collector moves objects.
  LockedSchemeObject interfaces(Svector_ref(cbs_vec, 11));
  cbs_ = unpack_callbacks(cbs_vec);
  initialize(interfaces);
}

std::optional<std::string>
validateSchemeDialect(const std::string& dialect_name,
                      const std::string& module_name) {
  auto interp = ChezSchemeInterpreter::instance(
      SchemeLogLevel::Warning, crest::registerMlirForeignFunctions);
  return interp->importDialectLibrary(module_name, dialect_name);
}

std::pair<mlir::TypeID, mlir::DialectAllocatorFunction>
dialectFactory(std::string dialect_name, std::string module_name) {
  auto type_id = CrestDialect::allocateTypeId();
  return {type_id,
          [type_id, dialect_name,
           module_name](mlir::MLIRContext* ctx) -> mlir::Dialect* {
            // USE-AFTER-FREE WARNING: the context keeps this name as a pointer
            // for as long as it lives, and `dialect_name` dies with the
            // factory. Give it the interned copy, which the context owns.
            llvm::StringRef name =
                mlir::StringAttr::get(ctx, dialect_name).getValue();
            return ctx->getOrLoadDialect(
                name, type_id, [&]() -> std::unique_ptr<mlir::Dialect> {
                  return std::make_unique<CrestDialect>(type_id, module_name,
                                                        dialect_name, ctx);
                });
          }};
}

} // namespace crest

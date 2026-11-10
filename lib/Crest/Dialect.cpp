/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// CrestDialect bridge — lib/Crest/Dialect.cpp

#include "Dialect.h"
#include "../Bindings/Support/CrestObject.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "Interface.h"
#include "llvm/ADT/DenseMap.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectImplementation.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Support/TypeID.h"
#include <memory>
#include <string>
#include <unordered_map>

namespace crest {

// ---------------------------------------------------------------------------
// Op-interface registry — file-local; accessed only via RegisterInterfaceForOp
// and getRegisteredInterfaceForOp.
// DenseMap is used because std::unordered_map requires std::hash<mlir::TypeID>
// which is not provided; llvm::DenseMapInfo<mlir::TypeID> is.
// ---------------------------------------------------------------------------

using OpInterfaceRegistry =
    llvm::DenseMap<mlir::TypeID,
                   std::unordered_map<std::string, std::shared_ptr<void>>>;
static OpInterfaceRegistry g_op_interface_registry;

bool RegisterInterfaceForOp(mlir::TypeID id, const std::string& op_name,
                            std::shared_ptr<void> concept_ptr) {
  auto& inner = g_op_interface_registry[id];
  if (inner.count(op_name)) {
    llvm::report_fatal_error(
        llvm::Twine("RegisterInterfaceForOp: duplicate registration for op '") +
        op_name + "'");
  }
  inner[op_name] = std::move(concept_ptr);
  return true;
}

void* CrestDialect::getRegisteredInterfaceForOp(mlir::TypeID interfaceID,
                                                mlir::OperationName opName) {
  return LookupInterfaceForOp(interfaceID, opName.getStringRef().str());
}

void* LookupInterfaceForOp(mlir::TypeID id, const std::string& op_name) {
  void* ret = nullptr;
  auto it = g_op_interface_registry.find(id);
  if (it != g_op_interface_registry.end()) {
    auto it2 = it->second.find(op_name);
    if (it2 != it->second.end()) {
      ret = it2->second.get();
    }
  }
  return ret;
}

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

bool CrestDialect::classof(const mlir::Dialect* d) {
  // Limitation: returns true for any ExtensibleDialect, not just CrestDialect.
  // Without a static C++ class per Scheme dialect there is no per-dialect
  // TypeID to check against — the same limitation applies to DynamicDialect.
  // Use d->getDialectNamespace() to identify a specific Scheme dialect.
  return mlir::isa<mlir::ExtensibleDialect>(d);
}

// ---------------------------------------------------------------------------
// Virtual method bridges
// ---------------------------------------------------------------------------

namespace {
// The text of an error that a Scheme verifier raised, which its callable gives
// (crest::CrestDialect::reportFailure) before it answers 0, so that the
// diagnostic can carry it.
std::string g_reported_failure;

mlir::LogicalResult verifyResult(mlir::Operation* op, int answer) {
  if (answer != 0) {
    return mlir::success();
  }
  if (g_reported_failure.empty()) {
    return mlir::failure();
  }
  std::string message = std::move(g_reported_failure);
  g_reported_failure.clear();
  return op->emitError() << message;
}
} // namespace

void CrestDialect::initialize() {
  // Load dependent dialects first. The callback gives each name of a dialect
  // namespace (e.g. "arith") to crest::CrestDialect::loadDependentDialect,
  // which calls getOrLoadDialect(name); MLIR finds the factory in the
  // DialectRegistry and instantiates it if not already loaded. That works for
  // built-in MLIR dialects the host registered (registry.insert<T>(),
  // registerAllDialects()) and for other Scheme dialects registered by name
  // (--crest-scheme-dialect).
  if (cbs_.get_dependent_dialects) {
    cbs_.get_dependent_dialects(reinterpret_cast<uint64_t>(this));
  }
  if (cbs_.initialize) {
    cbs_.initialize(reinterpret_cast<uint64_t>(this));
  }
}

mlir::Attribute CrestDialect::parseAttribute(mlir::DialectAsmParser& parser,
                                             mlir::Type type) const {
  if (cbs_.parse_attribute) {
    return mlir::Attribute::getFromOpaquePointer(
        reinterpret_cast<const void*>(cbs_.parse_attribute(
            reinterpret_cast<uint64_t>(&parser),
            reinterpret_cast<uint64_t>(type.getAsOpaquePointer()))));
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
    return mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(
        cbs_.parse_type(reinterpret_cast<uint64_t>(&parser))));
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
    return reinterpret_cast<mlir::Operation*>(cbs_.materialize_constant(
        reinterpret_cast<uint64_t>(&builder_shell),
        reinterpret_cast<uint64_t>(value.getAsOpaquePointer()),
        reinterpret_cast<uint64_t>(type.getAsOpaquePointer()),
        reinterpret_cast<uint64_t>(loc.getAsOpaquePointer())));
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
    return verifyResult(op,
                        cbs_.verify_op_attr(reinterpret_cast<uint64_t>(op),
                                            reinterpret_cast<uint64_t>(&attr)));
  }
  return mlir::ExtensibleDialect::verifyOperationAttribute(op, attr);
}

mlir::LogicalResult
CrestDialect::verifyRegionArgAttribute(mlir::Operation* op,
                                       unsigned regionIndex, unsigned argIndex,
                                       mlir::NamedAttribute attr) {
  if (cbs_.verify_region_arg_attr) {
    return verifyResult(op, cbs_.verify_region_arg_attr(
                                reinterpret_cast<uint64_t>(op), regionIndex,
                                argIndex, reinterpret_cast<uint64_t>(&attr)));
  }
  return mlir::ExtensibleDialect::verifyRegionArgAttribute(op, regionIndex,
                                                           argIndex, attr);
}

mlir::LogicalResult CrestDialect::verifyRegionResultAttribute(
    mlir::Operation* op, unsigned regionIndex, unsigned resultIndex,
    mlir::NamedAttribute attr) {
  if (cbs_.verify_region_result_attr) {
    return verifyResult(
        op, cbs_.verify_region_result_attr(reinterpret_cast<uint64_t>(op),
                                           regionIndex, resultIndex,
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
      scheme_error("crest::CrestDialect",
                   "callback slot must be the entry point of a callable or 0");
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
      (void*)+[](uint64_t dialect_ptr, const char* name) -> void {
        auto* dialect = reinterpret_cast<CrestDialect*>(dialect_ptr);
        if (!dialect->getContext()->getOrLoadDialect(llvm::StringRef(name))) {
          llvm::report_fatal_error(
              llvm::Twine("crest: dependent dialect not in registry: ") + name);
        }
      });

  // crest::CrestDialect::reportFailure (string message) → void
  //
  // The callable of a verifier calls it with the text of the error its Scheme
  // callback raised, before it answers 0, so that the diagnostic shows it.
  Sregister_symbol(
      "crest::CrestDialect::reportFailure",
      (void*)+[](const char* message) -> void {
        g_reported_failure = message;
      });

  // crest::load-scheme-dialect! (uptr ctx) (string dialect-name) (string
  // module-name) → void Loads a Scheme-defined dialect into an existing
  // MLIRContext by delegating to dialectFactory. Safe to call when
  // multiThreadedExecutionContext == 0 (e.g. standalone tools, toyc.sls).
  // Replaces the old crest::register-dialect!.
  Sregister_symbol(
      "crest::load-scheme-dialect!",
      (void*)+[](uint64_t ctx_ptr, const char* dialect_name,
                 const char* module_name) -> void {
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(
            ctx_ptr, "crest::load-scheme-dialect!");
        // Copy first: the strings point into the Scheme heap, which the Scheme
        // code that validateSchemeDialect runs may move.
        std::string dialect(dialect_name);
        std::string module(module_name);
        if (auto error = validateSchemeDialect(dialect, module)) {
          scheme_error("crest::load-scheme-dialect!",
                       "Failed to import Scheme library: " + module + ": " +
                           *error);
        }
        auto [type_id, factory] = dialectFactory(dialect, module);
        factory(ctx);
      });
}

// ---------------------------------------------------------------------------
// New 4-arg constructor and dialectFactory — placed after unpack_callbacks
// ---------------------------------------------------------------------------

CrestDialect::CrestDialect(mlir::TypeID id, const std::string& module_name,
                           const std::string& dialect_name,
                           mlir::MLIRContext* ctx)
    : mlir::ExtensibleDialect(dialect_name, ctx, id),
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
  if (!Svectorp(cbs_vec)) {
    // validateSchemeDialect reports this before a factory is registered; this
    // is the backstop for a caller that skipped it.
    llvm::report_fatal_error(
        llvm::Twine("CrestDialect: '") + dialect_name +
        "' of Scheme library '" + module_name +
        "' is not the callbacks vector define-dialect makes");
  }
  cbs_ = unpack_callbacks(cbs_vec);
  initialize();
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
            return ctx->getOrLoadDialect(
                dialect_name, type_id, [&]() -> std::unique_ptr<mlir::Dialect> {
                  return std::make_unique<CrestDialect>(type_id, module_name,
                                                        dialect_name, ctx);
                });
          }};
}

} // namespace crest

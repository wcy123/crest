/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// CrestDialect bridge — lib/Crest/Dialect.cpp

#include "Dialect.h"
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
    return false; // already registered — first wins
  }
  inner[op_name] = std::move(concept_ptr);
  return true;
}

void* CrestDialect::getRegisteredInterfaceForOp(mlir::TypeID interfaceID,
                                                mlir::OperationName opName) {
  return cbs_.register_op_interfaces(interfaceID, opName.getStringRef().str());
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
// Concept-creator dispatch table
// ---------------------------------------------------------------------------

static llvm::DenseMap<mlir::TypeID, ConceptCreatorFn> g_concept_creators;

void registerConceptCreator(mlir::TypeID id, ConceptCreatorFn fn) {
  g_concept_creators[id] = fn;
}

ConceptCreatorFn lookupConceptCreator(mlir::TypeID id) {
  auto it = g_concept_creators.find(id);
  return it != g_concept_creators.end() ? it->second : nullptr;
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

template <typename T> static T* ptr_from_scheme(ptr val) {
  return reinterpret_cast<T*>(static_cast<uint64_t>(Sinteger64_value(val)));
}

// ---------------------------------------------------------------------------
// CrestDialect — constructor and classof
// ---------------------------------------------------------------------------

mlir::TypeID CrestDialect::allocateTypeId() {
  return g_crest_type_id_allocator.allocate();
}

CrestDialect::CrestDialect(llvm::StringRef name, mlir::MLIRContext* ctx,
                           mlir::TypeID id, Callbacks cbs)
    : mlir::ExtensibleDialect(name, ctx, id), cbs_(std::move(cbs)) {
  initialize();
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

void CrestDialect::initialize() {
  // Load dependent dialects first.
  //
  // The callback returns a Scheme list of uptr values, each a pointer to a
  // null-terminated C string naming a dialect namespace (e.g. "arith").
  // We call getOrLoadDialect(name) for each; MLIR finds the factory in the
  // DialectRegistry and instantiates it if not already loaded.
  //
  // This works for:
  //   - Built-in MLIR dialects (arith, func, ...) that the host registered via
  //     registry.insert<T>() or registerAllDialects().
  //   - Other Scheme-defined CrestDialects that were previously registered via
  //     crest::register-dialect! (which uses DialectRegistry::insert with a
  //     pre-allocated TypeID, making them findable by name).
  //
  // Note: getOrLoadDialect returns nullptr if the name is not in the registry.
  // For CrestDialects, this means register-dialect! must be called for all
  // dependencies before any dialect that needs them is loaded. The Scheme-side
  // load-dialect! wrapper enforces this ordering.
  if (cbs_.get_dependent_dialects.get() != Sfalse) {
    ptr deps = scheme_call(cbs_.get_dependent_dialects.get());
    for (; deps != Snil; deps = Scdr(deps)) {
      auto* ns = reinterpret_cast<const char*>(
          static_cast<uint64_t>(Sinteger64_value(Scar(deps))));
      if (!getContext()->getOrLoadDialect(llvm::StringRef(ns))) {
        llvm::report_fatal_error(
            llvm::Twine("crest: dependent dialect not in registry: ") + ns);
      }
    }
  }
  if (cbs_.initialize.get() != Sfalse) {
    scheme_call(cbs_.initialize.get(), this);
  }
}

mlir::Attribute CrestDialect::parseAttribute(mlir::DialectAsmParser& parser,
                                             mlir::Type type) const {
  if (cbs_.parse_attribute.get() != Sfalse) {
    return mlir::Attribute::getFromOpaquePointer(
        ptr_from_scheme<void>(scheme_call(cbs_.parse_attribute.get(), &parser,
                                          type.getAsOpaquePointer())));
  }
  return mlir::ExtensibleDialect::parseAttribute(parser, type);
}

void CrestDialect::printAttribute(mlir::Attribute attr,
                                  mlir::DialectAsmPrinter& os) const {
  if (cbs_.print_attribute.get() != Sfalse) {
    scheme_call(cbs_.print_attribute.get(), attr.getAsOpaquePointer(), &os);
  } else {
    mlir::ExtensibleDialect::printAttribute(attr, os);
  }
}

mlir::Type CrestDialect::parseType(mlir::DialectAsmParser& parser) const {
  if (cbs_.parse_type.get() != Sfalse) {
    return mlir::Type::getFromOpaquePointer(
        ptr_from_scheme<void>(scheme_call(cbs_.parse_type.get(), &parser)));
  }
  return mlir::ExtensibleDialect::parseType(parser);
}

void CrestDialect::printType(mlir::Type type,
                             mlir::DialectAsmPrinter& os) const {
  if (cbs_.print_type.get() != Sfalse) {
    scheme_call(cbs_.print_type.get(), type.getAsOpaquePointer(), &os);
  } else {
    mlir::ExtensibleDialect::printType(type, os);
  }
}

mlir::Operation* CrestDialect::materializeConstant(mlir::OpBuilder& builder,
                                                   mlir::Attribute value,
                                                   mlir::Type type,
                                                   mlir::Location loc) {
  if (cbs_.materialize_constant.get() != Sfalse) {
    return ptr_from_scheme<mlir::Operation>(scheme_call(
        cbs_.materialize_constant.get(), &builder, value.getAsOpaquePointer(),
        type.getAsOpaquePointer(), loc.getAsOpaquePointer()));
  }
  return mlir::ExtensibleDialect::materializeConstant(builder, value, type,
                                                      loc);
}

void CrestDialect::getCanonicalizationPatterns(
    mlir::RewritePatternSet& results) const {
  if (cbs_.get_canonicalization_patterns.get() != Sfalse) {
    scheme_call(cbs_.get_canonicalization_patterns.get(), &results);
  } else {
    mlir::ExtensibleDialect::getCanonicalizationPatterns(results);
  }
}

mlir::LogicalResult
CrestDialect::verifyOperationAttribute(mlir::Operation* op,
                                       mlir::NamedAttribute attr) {
  if (cbs_.verify_op_attr.get() != Sfalse) {
    return Sboolean_value(scheme_call(cbs_.verify_op_attr.get(), op, &attr))
               ? mlir::success()
               : mlir::failure();
  }
  return mlir::ExtensibleDialect::verifyOperationAttribute(op, attr);
}

mlir::LogicalResult
CrestDialect::verifyRegionArgAttribute(mlir::Operation* op,
                                       unsigned regionIndex, unsigned argIndex,
                                       mlir::NamedAttribute attr) {
  if (cbs_.verify_region_arg_attr.get() != Sfalse) {
    return Sboolean_value(scheme_call(cbs_.verify_region_arg_attr.get(), op,
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
  if (cbs_.verify_region_result_attr.get() != Sfalse) {
    return Sboolean_value(scheme_call(cbs_.verify_region_result_attr.get(), op,
                                      regionIndex, resultIndex, &attr))
               ? mlir::success()
               : mlir::failure();
  }
  return mlir::ExtensibleDialect::verifyRegionResultAttribute(
      op, regionIndex, resultIndex, attr);
}

// ---------------------------------------------------------------------------
// Helpers for Sregister_symbol bindings
// ---------------------------------------------------------------------------

static std::shared_ptr<CrestDialect::Callbacks> unpack_callbacks(ptr cbs_ptr) {
  auto make_cb = [](ptr slot) -> LockedSchemeObject {
    if (Sprocedurep(slot)) {
      return LockedSchemeObject(slot);
    }
    if (slot != Sfalse) {
      scheme_error("crest::register-dialect!",
                   "callback slot must be a procedure or #f");
    }
    return LockedSchemeObject();
  };
  ptr v = cbs_ptr;
  auto cbs = std::make_shared<CrestDialect::Callbacks>();
  cbs->initialize = make_cb(Svector_ref(v, 0));
  cbs->get_dependent_dialects = make_cb(Svector_ref(v, 1));
  cbs->parse_attribute = make_cb(Svector_ref(v, 2));
  cbs->print_attribute = make_cb(Svector_ref(v, 3));
  cbs->parse_type = make_cb(Svector_ref(v, 4));
  cbs->print_type = make_cb(Svector_ref(v, 5));
  cbs->materialize_constant = make_cb(Svector_ref(v, 6));
  cbs->get_canonicalization_patterns = make_cb(Svector_ref(v, 7));
  cbs->verify_op_attr = make_cb(Svector_ref(v, 8));
  cbs->verify_region_arg_attr = make_cb(Svector_ref(v, 9));
  cbs->verify_region_result_attr = make_cb(Svector_ref(v, 10));
  cbs->register_op_interfaces = LookupInterfaceForOp;
  return cbs;
}

// ---------------------------------------------------------------------------
// Sregister_symbol bindings
// ---------------------------------------------------------------------------

void registerIRExtensibleDialectBindings() {
  // crest::load-scheme-dialect! (uptr ctx) (string dialect-name) (string
  // module-name) → void Loads a Scheme-defined dialect into an existing
  // MLIRContext by delegating to dialectFactory. Safe to call when
  // multiThreadedExecutionContext == 0 (e.g. standalone tools, toyc.sls).
  // Replaces the old crest::register-dialect!.
  Sregister_symbol(
      "crest::load-scheme-dialect!",
      (void*)+[](uint64_t ctx_ptr, const char* dialect_name,
                 const char* module_name) -> void {
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        auto [type_id, factory] =
            dialectFactory(std::string(dialect_name), std::string(module_name));
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
  interp_->importLibrary(module_name);
  // Call get-<dialect>-callbacks() — a 0-arg function auto-generated by
  // define-dialect via datum->syntax (user scope, not macro scope), so it
  // is accessible by datum name from C++ via scheme_call after import.
  std::string get_fn = "get-" + dialect_name + "-callbacks";
  ptr cbs_vec = scheme_call(get_fn.c_str());
  cbs_ = std::move(*unpack_callbacks(cbs_vec));
  initialize();
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

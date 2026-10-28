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
static std::unordered_map<std::string, ConceptCreatorFn>
    g_concept_creators_by_name;

void registerConceptCreator(mlir::TypeID id, ConceptCreatorFn fn) {
  g_concept_creators[id] = fn;
}

void registerConceptCreatorByName(const std::string& name,
                                  ConceptCreatorFn fn) {
  g_concept_creators_by_name[name] = fn;
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

// Register a dialect factory and immediately load the dialect.
//
// appendDialectRegistry asserts multiThreadedExecutionContext == 0, which the
// pass manager increments before any pass runs. We bracket the call with
// exit/enter so the assertion passes. This is safe because CrestPass is
// single-threaded.
//
// We must NOT use getOrLoadDialect here: it immediately replaces existing
// UnregisteredOpModel entries in the context, freeing the Impl objects that
// already-parsed Operation::name fields point to. That causes use-after-free
// when op->getName() is called after the dialect is loaded.
// appendDialectRegistry only registers a factory — loading is lazy — so
// existing Operation::name pointers remain valid.
static void insertDialectFactory(mlir::MLIRContext* ctx, mlir::TypeID id,
                                 llvm::StringRef name,
                                 mlir::DialectAllocatorFunction factory) {
  ctx->exitMultiThreadedExecution();
  mlir::DialectRegistry tmp;
  tmp.insert(id, name, std::move(factory));
  ctx->appendDialectRegistry(tmp);
  ctx->enterMultiThreadedExecution();
}

// ---------------------------------------------------------------------------
// CrestDialect — constructor and classof
// ---------------------------------------------------------------------------

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
  // crest::register-dialect! (uptr ctx) (uptr name-cstr) (uptr vector/12)
  // Registers a factory in the DialectRegistry so getOrLoadDialect("name")
  // instantiates the CrestDialect on demand.  Loading is deferred.
  //
  // Callback vector slots (#f = use ExtensibleDialect default):
  //   0 initialize                       6 materialize-constant
  //   1 get-dependent-dialects           7 get-canonicalization-patterns
  //   2 parse-attribute                  8 verify-op-attr
  //   3 print-attribute                  9 verify-region-arg-attr
  //   4 parse-type                      10 verify-region-result-attr
  //   5 print-type
  Sregister_symbol(
      "crest::register-dialect!",
      (void*)+[](uint64_t ctx_ptr, uint64_t name_ptr, ptr cbs_ptr) -> void {
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        std::string name(reinterpret_cast<const char*>(name_ptr));

        // Already registered? Do nothing — idempotent.
        if (ctx->getDialectRegistry().getDialectAllocator(name)) {
          return;
        }

        // shared_ptr from unpack_callbacks: keeps LockedSchemeObject GC locks
        // alive for the factory's lifetime; also makes the lambda copyable for
        // std::function (Callbacks is move-only, shared_ptr is copyable).
        auto cbs_ptr2 = unpack_callbacks(cbs_ptr);

        // Allocate id before registering the factory so the factory lambda and
        // the CrestDialect constructor both receive the same TypeID.
        //
        // MLIRContext maintains two indexes for loaded dialects: one keyed by
        // namespace string and one keyed by TypeID. The TypeID stored in the
        // Dialect object (via Dialect::getTypeID(), set in the constructor)
        // must match the TypeID recorded in the DialectRegistry entry.
        // A mismatch leaves the TypeID index stale — getOrLoadDialect(TypeID)
        // would not find the dialect, breaking any code path that looks up a
        // dialect by type rather than by name.
        //
        // Scope: id is permanent for the life of the process, matching the
        // lifetime of static C++ dialect TypeIDs.
        //
        // Uniqueness: each call to crest::register-dialect! allocates a fresh
        // id. Within one context the name check above (getDialectAllocator)
        // ensures only one id is ever allocated per dialect name. Across
        // contexts the same name gets a different id — this is intentional,
        // since MLIR contexts are isolated and cross-context TypeID comparison
        // is not supported.
        mlir::TypeID id = g_crest_type_id_allocator.allocate();

        insertDialectFactory(
            ctx, id, name,
            [id, name,
             cbs_ptr2](mlir::MLIRContext* load_ctx) -> mlir::Dialect* {
              if (!cbs_ptr2.get()) {
                llvm::report_fatal_error(
                    "crest::register-dialect!: factory called more than once "
                    "— getOrLoadDialect guarantees at-most-once per context");
              }
              return new CrestDialect(name, load_ctx, id, std::move(*cbs_ptr2));
            });
      });

  // crest::register-interface! — call the concept creator for a named
  // interface. Takes the interface name as a C string and the Scheme dispatcher
  // procedure. Used by :interfaces DSL generated code to avoid hygiene issues
  // with interface-specific identifiers in macro output.
  Sregister_symbol(
      "crest::register-interface!",
      (void*)+[](ptr name_obj, ptr dispatcher) -> void {
        iptr len = Sstring_length(name_obj);
        std::string name;
        name.reserve(static_cast<size_t>(len));
        for (iptr i = 0; i < len; ++i) {
          name += static_cast<char>(Sstring_ref(name_obj, i) & 0xFF);
        }
        auto it = g_concept_creators_by_name.find(name);
        if (it == g_concept_creators_by_name.end()) {
          scheme_error("crest::register-interface!",
                       "unknown interface:", name.c_str());
        }
        it->second(dispatcher);
      });
}

} // namespace crest

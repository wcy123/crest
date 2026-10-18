/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Mirrors mlir/IR/ExtensibleDialect.h

#include "ExtensibleDialect.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectImplementation.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Support/TypeID.h"
#include <memory>

namespace crest {

// ---------------------------------------------------------------------------
// Global TypeID allocator
//
// Scheme dialects are defined at runtime and have no C++ class, so they
// cannot use MLIR_DECLARE_EXPLICIT_TYPE_ID (which requires a static storage
// variable per class, established at link time).
//
// mlir::TypeIDAllocator pre-allocates stable TypeID storage independently of
// any Dialect object. The allocated IDs remain valid for the lifetime of the
// allocator. Since dialects live as long as the MLIRContext (which lives as
// long as the process in typical CREST usage), a process-lifetime allocator
// is correct.
//
// Thread safety: TypeIDAllocator uses a bump-pointer allocator that is NOT
// thread-safe. CREST's Chez Scheme runtime is single-threaded, so this is
// safe. Add a mutex if multithreaded dialect registration is ever needed.
// ---------------------------------------------------------------------------
static mlir::TypeIDAllocator g_crest_type_id_allocator;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

template <typename T> static T* ptr_from_scheme(ptr val) {
  return reinterpret_cast<T*>(static_cast<uint64_t>(Sinteger64_value(val)));
}

// MLIRContext::getDialectRegistry() returns const DialectRegistry& by design.
// Mutable access was deliberately removed (commit 2996a8d, reviewed in D96331)
// to enable safe delayed dialect interface registration: appendDialectRegistry
// calls applyExtensions(ctx) on already-loaded dialects as a side effect,
// which raw mutable insertion would bypass. The two-step pattern
// (build a DialectRegistry, then appendDialectRegistry) is the intended idiom.
// We wrap it in a helper to keep call sites readable.
static void insertDialectFactory(mlir::MLIRContext* ctx, mlir::TypeID id,
                                 llvm::StringRef name,
                                 mlir::DialectAllocatorFunction factory) {
  mlir::DialectRegistry tmp;
  tmp.insert(id, name, std::move(factory));
  ctx->appendDialectRegistry(tmp);
}

// ---------------------------------------------------------------------------
// CrestDialect — constructor and classof
// ---------------------------------------------------------------------------

CrestDialect::CrestDialect(llvm::StringRef name, mlir::MLIRContext* ctx,
                           mlir::TypeID id, Callbacks cbs)
    : mlir::ExtensibleDialect(name, ctx, id), cbs_(std::move(cbs)) {}

bool CrestDialect::classof(const mlir::Dialect* d) {
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
  if (cbs_.get_dependent_dialects) {
    ptr deps = scheme_call(cbs_.get_dependent_dialects->get());
    for (; deps != Snil; deps = Scdr(deps)) {
      auto* ns = reinterpret_cast<const char*>(
          static_cast<uint64_t>(Sinteger64_value(Scar(deps))));
      if (!getContext()->getOrLoadDialect(llvm::StringRef(ns))) {
        llvm::report_fatal_error(
            llvm::Twine("crest: dependent dialect not in registry: ") + ns);
      }
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
  // crest::register-dialect!
  //
  // Registers a Scheme-defined dialect into the MLIRContext's DialectRegistry
  // so that ctx->getOrLoadDialect("name") can instantiate it on demand.
  //
  // This replaces the earlier crest::load-dialect! approach that called
  // getOrLoadDialect(name, id, ctor) directly. The registry approach is
  // superior because:
  //
  //   1. Lazy loading: the CrestDialect object is only created when first
  //      needed, not at registration time.
  //
  //   2. Dependency resolution: other dialects (including CrestDialects) can
  //      declare this dialect as a dependency via get_dependent_dialects and
  //      MLIR will call getOrLoadDialect("name") to resolve it — which works
  //      because the factory is now in the registry.
  //
  //   3. Consistent TypeID: the same TypeID (pre-allocated from
  //      g_crest_type_id_allocator) is used both in the registry entry and in
  //      the CrestDialect constructor. This is critical — if two different
  //      TypeIDs were used for the same dialect name, MLIR's isa<>/dyn_cast<>
  //      and interface lookup would silently break.
  //
  // TypeID note: we cannot use mlir::SelfOwningTypeID (address of an in-object
  // storage field) because the TypeID must be known before the object exists
  // (to register the factory). mlir::TypeIDAllocator pre-allocates stable
  // heap storage whose address serves as the TypeID.
  //
  // Callback vector slots (Sfalse = use ExtensibleDialect default):
  //   0 initialize                       6 materialize-constant
  //   1 get-dependent-dialects           7 get-canonicalization-patterns
  //   2 parse-attribute                  8 verify-op-attr
  //   3 print-attribute                  9 verify-region-arg-attr
  //   4 parse-type                      10 verify-region-result-attr
  //   5 print-type                      11 get-registered-interface-for-op
  //
  // Args: (uptr ctx) (uptr name-cstr) (uptr scheme-vector-of-12-callbacks)
  // Returns: void (loading is deferred to getOrLoadDialect)
  Sregister_symbol(
      "crest::register-dialect!",
      (void*)+[](uint64_t ctx_ptr, uint64_t name_ptr,
                 uint64_t cbs_ptr) -> void {
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        std::string name(reinterpret_cast<const char*>(name_ptr));

        // Already registered? Do nothing — idempotent.
        if (ctx->getDialectRegistry().getDialectAllocator(name)) {
          return;
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

        // Pre-allocate a stable TypeID. The SAME id is captured in the factory
        // lambda and passed to the CrestDialect constructor — this is the
        // invariant that keeps the registry entry and the Dialect object in
        // sync.
        mlir::TypeID id = g_crest_type_id_allocator.allocate();

        // Wrap callbacks in a shared_ptr so the factory lambda is copyable
        // (required by std::function<Dialect*(MLIRContext*)>).
        // LockedSchemeObject is move-only, so CrestDialect::Callbacks is
        // move-only; shared_ptr allows the lambda to be copied while the
        // callbacks themselves are stored once.
        // The factory is called at most once per dialect name (getOrLoadDialect
        // checks loaded state first), so moving from *cbs_ptr on first call
        // is safe.
        auto cbs_ptr2 =
            std::make_shared<CrestDialect::Callbacks>(std::move(cbs));

        insertDialectFactory(
            ctx, id, name,
            [id, name,
             cbs_ptr2](mlir::MLIRContext* load_ctx) -> mlir::Dialect* {
              return new CrestDialect(name, load_ctx, id, std::move(*cbs_ptr2));
            });
      });
}

} // namespace crest

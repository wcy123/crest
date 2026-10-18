/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// CrestOp bridge — lib/Crest/Op.cpp

#include "Op.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

// ---------------------------------------------------------------------------
// Helpers — build llvm::unique_function types from optional Scheme callbacks.
//
// Each helper takes the optional callback and returns the appropriate function
// object. When the callback is absent, a no-op or always-success default is
// returned so the caller can always use the full DynamicOpDefinition::get
// overload without branching on which slots are set.
// ---------------------------------------------------------------------------

static mlir::OperationName::VerifyInvariantsFn
make_verify_fn(std::optional<LockedSchemeObject> cb) {
  if (!cb) {
    return [](mlir::Operation*) { return mlir::success(); };
  }
  return [cb = std::move(*cb)](mlir::Operation* op) {
    return Sboolean_value(scheme_call(cb.get(), op)) ? mlir::success()
                                                     : mlir::failure();
  };
}

static mlir::OperationName::ParseAssemblyFn
make_parse_fn(std::optional<LockedSchemeObject> cb) {
  if (!cb) {
    return [](mlir::OpAsmParser&, mlir::OperationState&) {
      return mlir::ParseResult::success();
    };
  }
  return [cb = std::move(*cb)](mlir::OpAsmParser& parser,
                               mlir::OperationState& state) {
    return Sboolean_value(scheme_call(cb.get(), &parser, &state))
               ? mlir::ParseResult::success()
               : mlir::ParseResult::failure();
  };
}

static mlir::OperationName::PrintAssemblyFn
make_print_fn(std::optional<LockedSchemeObject> cb) {
  if (!cb) {
    return [](mlir::Operation*, mlir::OpAsmPrinter&, llvm::StringRef) {};
  }
  return [cb = std::move(*cb)](mlir::Operation* op, mlir::OpAsmPrinter& printer,
                               llvm::StringRef name) {
    std::string name_str = name.str();
    scheme_call(cb.get(), op, &printer, name_str.c_str());
  };
}

static mlir::OperationName::FoldHookFn
make_fold_fn(std::optional<LockedSchemeObject> cb) {
  if (!cb) {
    return [](mlir::Operation*, llvm::ArrayRef<mlir::Attribute>,
              llvm::SmallVectorImpl<mlir::OpFoldResult>&) {
      return mlir::failure();
    };
  }
  // Scheme callback: (op) → bool.  Fold results not yet bridged —
  // returning failure when the Scheme side cannot fold is correct.
  return [cb = std::move(*cb)](mlir::Operation* op,
                               llvm::ArrayRef<mlir::Attribute>,
                               llvm::SmallVectorImpl<mlir::OpFoldResult>&) {
    return Sboolean_value(scheme_call(cb.get(), op)) ? mlir::success()
                                                     : mlir::failure();
  };
}

static mlir::DynamicOpDefinition::GetCanonicalizationPatternsFn
make_canon_fn(std::optional<LockedSchemeObject> cb) {
  if (!cb) {
    return [](mlir::RewritePatternSet&, mlir::MLIRContext*) {};
  }
  // Scheme callback: (pattern-set-ptr ctx-ptr) → void.
  // The Scheme side calls add-rewrite-pattern on the pattern set.
  return [cb = std::move(*cb)](mlir::RewritePatternSet& patterns,
                               mlir::MLIRContext* ctx) {
    scheme_call(cb.get(), &patterns, ctx);
  };
}

static mlir::OperationName::PopulateDefaultAttrsFn
make_default_attrs_fn(std::optional<LockedSchemeObject> cb) {
  if (!cb) {
    return [](const mlir::OperationName&, mlir::NamedAttrList&) {};
  }
  // Scheme callback: (op-name-ptr attr-list-ptr) → void.
  return [cb = std::move(*cb)](const mlir::OperationName& name,
                               mlir::NamedAttrList& attrs) {
    scheme_call(cb.get(), &name, &attrs);
  };
}

// ---------------------------------------------------------------------------
// CrestOp::registerInto
// ---------------------------------------------------------------------------

void CrestOp::registerInto(mlir::ExtensibleDialect* dialect,
                           llvm::StringRef op_name, Callbacks cbs) {
  auto verify_fn = make_verify_fn(std::move(cbs.verify));
  auto verify_region_fn = make_verify_fn(std::move(cbs.verify_regions));

  // Use 2-arg or 4-arg overload for parse/print to preserve MLIR's generic
  // assembly format default when no custom parse/print is provided.
  // Wire fold/canonicalization/populate-default-attrs via setXxx so all
  // 7 slots are honoured without losing the generic format default.
  std::unique_ptr<mlir::DynamicOpDefinition> def;
  if (cbs.parse || cbs.print) {
    def = mlir::DynamicOpDefinition::get(op_name, dialect, std::move(verify_fn),
                                         std::move(verify_region_fn),
                                         make_parse_fn(std::move(cbs.parse)),
                                         make_print_fn(std::move(cbs.print)));
  } else {
    def = mlir::DynamicOpDefinition::get(op_name, dialect, std::move(verify_fn),
                                         std::move(verify_region_fn));
  }

  if (cbs.fold) {
    def->setFoldHookFn(make_fold_fn(std::move(cbs.fold)));
  }
  if (cbs.get_canonicalization_patterns) {
    def->setGetCanonicalizationPatternsFn(
        make_canon_fn(std::move(cbs.get_canonicalization_patterns)));
  }
  if (cbs.populate_default_attrs) {
    def->setPopulateDefaultAttrsFn(
        make_default_attrs_fn(std::move(cbs.populate_default_attrs)));
  }

  dialect->registerDynamicOp(std::move(def));
}

// ---------------------------------------------------------------------------
// Sregister_symbol binding
// ---------------------------------------------------------------------------

void registerCrestDynamicOpBindings() {
  // crest::register-dynamic-op! (uptr dialect) (string op-name) (uptr vector/7)
  //
  // Must be called from inside the dialect's :initialize callback.
  // Callback vector slots (#f = use MLIR default):
  //   0 verify          (op) → bool
  //   1 verify-regions  (op) → bool
  //   2 parse           (parser state) → bool   [#f = generic format]
  //   3 print           (op printer name) → void [#f = generic format]
  //   4 fold            (op) → bool
  //   5 get-canonicalization-patterns (pattern-set-ptr ctx-ptr) → void
  //   6 populate-default-attrs        (op-name-ptr attr-list-ptr) → void
  Sregister_symbol(
      "crest::register-dynamic-op!",
      (void*)+[](uint64_t dialect_ptr, const char* op_name,
                 uint64_t cbs_ptr) -> void {
        auto* dialect = reinterpret_cast<mlir::ExtensibleDialect*>(dialect_ptr);
        ptr v = reinterpret_cast<ptr>(cbs_ptr);

        auto make_cb = [](ptr slot) -> std::optional<LockedSchemeObject> {
          if (slot == Sfalse) {
            return std::nullopt;
          }
          return LockedSchemeObject(slot);
        };

        CrestOp::Callbacks cbs;
        cbs.verify = make_cb(Svector_ref(v, 0));
        cbs.verify_regions = make_cb(Svector_ref(v, 1));
        cbs.parse = make_cb(Svector_ref(v, 2));
        cbs.print = make_cb(Svector_ref(v, 3));
        cbs.fold = make_cb(Svector_ref(v, 4));
        cbs.get_canonicalization_patterns = make_cb(Svector_ref(v, 5));
        cbs.populate_default_attrs = make_cb(Svector_ref(v, 6));

        CrestOp::registerInto(dialect, op_name, std::move(cbs));
      });
}

} // namespace crest

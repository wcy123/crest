/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// CrestOp bridge — lib/Crest/Op.cpp

#include "Op.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "Trait.h"
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
make_parse_fn(LockedSchemeObject cb) {
  return [cb = std::move(cb)](mlir::OpAsmParser& parser,
                              mlir::OperationState& state) {
    return Sboolean_value(scheme_call(cb.get(), &parser, &state))
               ? mlir::ParseResult::success()
               : mlir::ParseResult::failure();
  };
}

static mlir::OperationName::PrintAssemblyFn
make_print_fn(LockedSchemeObject cb) {
  return [cb = std::move(cb)](mlir::Operation* op, mlir::OpAsmPrinter& printer,
                              llvm::StringRef defaultDialect) {
    // printAssembly must print the op name first, then the rest.
    llvm::StringRef opName = op->getName().getStringRef();
    if (!defaultDialect.empty() &&
        opName.starts_with((defaultDialect + ".").str())) {
      opName = opName.drop_front(defaultDialect.size() + 1);
    }
    printer << opName;
    std::string op_name_str = op->getName().getStringRef().str();
    scheme_call(cb.get(), op, &printer, op_name_str.c_str());
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
  // Scheme callback: (op operand-attributes) -> #f | list of results.
  // operand-attributes has one entry per operand, the constant attribute it
  // folds to or #f. A result is (value . v) or (attribute . a), as made by
  // fold-value and fold-attribute; the empty list means the op was folded in
  // place.
  return [cb = std::move(*cb)](
             mlir::Operation* op, llvm::ArrayRef<mlir::Attribute> operandAttrs,
             llvm::SmallVectorImpl<mlir::OpFoldResult>& results) {
    ptr attrList = Snil;
    for (auto it = operandAttrs.rbegin(); it != operandAttrs.rend(); ++it) {
      ptr entry = *it ? Sunsigned64(reinterpret_cast<uint64_t>(
                            it->getAsOpaquePointer()))
                      : Sfalse;
      attrList = Scons(entry, attrList);
    }
    LockedSchemeObject result(scheme_call(cb.get(), op, attrList));
    if (result.get() == Sfalse) {
      return mlir::failure();
    }
    ptr valueSymbol = Sstring_to_symbol("value");
    ptr attributeSymbol = Sstring_to_symbol("attribute");
    llvm::SmallVector<mlir::OpFoldResult> folded;
    for (ptr l = result.get(); Spairp(l); l = Scdr(l)) {
      ptr entry = Scar(l);
      if (!Spairp(entry) ||
          (Scar(entry) != valueSymbol && Scar(entry) != attributeSymbol)) {
        op->emitError("fold callback: a result must be made by fold-value or "
                      "fold-attribute");
        return mlir::failure();
      }
      void* raw = reinterpret_cast<void*>(Sunsigned64_value(Scdr(entry)));
      if (Scar(entry) == valueSymbol) {
        folded.push_back(mlir::Value::getFromOpaquePointer(raw));
      } else {
        folded.push_back(mlir::Attribute::getFromOpaquePointer(raw));
      }
    }
    if (!folded.empty() && folded.size() != op->getNumResults()) {
      op->emitError("fold callback returned ")
          << folded.size() << " results for an op with " << op->getNumResults();
      return mlir::failure();
    }
    results.append(folded.begin(), folded.end());
    return mlir::success();
  };
}

static mlir::DynamicOpDefinition::GetCanonicalizationPatternsFn
make_canon_fn(std::optional<LockedSchemeObject> cb) {
  if (!cb) {
    return [](mlir::RewritePatternSet&, mlir::MLIRContext*) {};
  }
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

  // DynamicOpDefinition::get adds "dialect_namespace." prefix internally.
  // op_name arrives as "toy.constant" (fully qualified); strip the prefix.
  llvm::StringRef unqualified = op_name;
  llvm::StringRef ns = dialect->getNamespace();
  if (unqualified.starts_with((ns + ".").str())) {
    unqualified = unqualified.drop_front(ns.size() + 1);
  }

  // Use the 2-arg get() so MLIR installs its own generic assembly format
  // defaults (printGenericOp for print, parse-error for parse).
  // Then override each slot individually via set*() if the user provided
  // a callback — no branching on combinations of slots.
  auto def = mlir::DynamicOpDefinition::get(
      unqualified, dialect, std::move(verify_fn), std::move(verify_region_fn));
  if (cbs.parse) {
    def->setParseFn(make_parse_fn(std::move(*cbs.parse)));
  }
  if (cbs.print) {
    def->setPrintFn(make_print_fn(std::move(*cbs.print)));
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

  std::string trait_error = addOpTraits(*def, op_name, cbs.traits);
  if (!trait_error.empty()) {
    scheme_error("crest::register-dynamic-op!",
                 op_name.str() + ": " + trait_error);
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
  //   7 traits                        list of (name arg ...) lists of strings
  Sregister_symbol(
      "crest::register-dynamic-op!",
      (void*)+[](uint64_t dialect_ptr, const char* op_name,
                 ptr cbs_ptr) -> void {
        auto* dialect = reinterpret_cast<mlir::ExtensibleDialect*>(dialect_ptr);
        ptr v = cbs_ptr;

        auto make_cb = [](ptr slot) -> std::optional<LockedSchemeObject> {
          if (Sprocedurep(slot)) {
            return LockedSchemeObject(slot);
          }
          if (slot != Sfalse) {
            scheme_error("crest::register-dynamic-op!",
                         "callback slot must be a procedure or #f");
          }
          return std::nullopt;
        };

        CrestOp::Callbacks cbs;
        cbs.verify = make_cb(Svector_ref(v, 0));
        cbs.verify_regions = make_cb(Svector_ref(v, 1));
        cbs.parse = make_cb(Svector_ref(v, 2));
        cbs.print = make_cb(Svector_ref(v, 3));
        cbs.fold = make_cb(Svector_ref(v, 4));
        cbs.get_canonicalization_patterns = make_cb(Svector_ref(v, 5));
        cbs.populate_default_attrs = make_cb(Svector_ref(v, 6));
        auto to_string = [](ptr name) {
          if (!Sstringp(name)) {
            scheme_error("crest::register-dynamic-op!",
                         "trait names and arguments must be strings");
          }
          std::string s;
          for (iptr i = 0; i < Sstring_length(name); ++i) {
            s.push_back(static_cast<char>(Sstring_ref(name, i)));
          }
          return s;
        };
        // slot 7: a list of (name arg ...) lists of strings
        for (ptr l = Svector_ref(v, 7); !Snullp(l); l = Scdr(l)) {
          std::vector<std::string> spec;
          for (ptr e = Scar(l); !Snullp(e); e = Scdr(e)) {
            spec.push_back(to_string(Scar(e)));
          }
          cbs.traits.push_back(std::move(spec));
        }

        CrestOp::registerInto(dialect, op_name, std::move(cbs));
      });
}

} // namespace crest

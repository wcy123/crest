/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// CrestOp bridge — lib/Crest/Op.cpp

#include "Op.h"
#include "../Bindings/IR/SymbolInterfaces.h"
#include "../Bindings/Interfaces/CallInterfaces.h"
#include "../Bindings/Interfaces/FunctionInterfaces.h"
#include "../Bindings/Interfaces/SideEffectInterfaces.h"
#include "../Bindings/Support/CrestObject.h"
#include "../Bindings/Support/LockedSchemeObject.h"
#include "../Bindings/Support/Result.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "InferType.h"
#include "Interface.h"
#include "Trait.h"
#include "llvm/ADT/DenseMap.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/Interfaces/CallInterfaces.h"
#include "mlir/Interfaces/FunctionInterfaces.h"
#include "mlir/Interfaces/InferTypeOpInterface.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"
#include "mlir/Support/TypeID.h"

namespace crest {

namespace {

// What MLIR collects while a folder runs; Scheme pushes into it.
using FoldedResults = llvm::SmallVector<mlir::OpFoldResult>;

// How an interface whose methods come from Scheme is installed in the
// definition of an op: from its dispatcher of C, locked by the caller for the
// call, before the op is registered. Keyed by the TypeID of the interface.
using AttachInterfaceFn = void (*)(mlir::DynamicOpDefinition& def,
                                   const LockedSchemeObject& dispatcher);

const llvm::DenseMap<mlir::TypeID, AttachInterfaceFn>& getAttachInterfaceFns() {
  static const llvm::DenseMap<mlir::TypeID, AttachInterfaceFn> fns = {
      {mlir::InferTypeOpInterface::getInterfaceID(),
       attachInferTypeOpInterface},
      {mlir::CallableOpInterface::getInterfaceID(), attachCallableOpInterface},
      {mlir::CallOpInterface::getInterfaceID(), attachCallOpInterface},
      {mlir::ArgAndResultAttrsOpInterface::getInterfaceID(),
       attachArgAndResultAttrsOpInterface},
      {mlir::FunctionOpInterface::getInterfaceID(), attachFunctionOpInterface},
      {mlir::SymbolOpInterface::getInterfaceID(), attachSymbolOpInterface},
      {mlir::MemoryEffectOpInterface::getInterfaceID(),
       attachMemoryEffectOpInterface},
      {mlir::ConditionallySpeculatable::getInterfaceID(),
       attachConditionallySpeculatable},
  };
  return fns;
}

} // namespace

// ---------------------------------------------------------------------------
// Helpers — build llvm::unique_function types from the entry points. When a
// slot is absent, a no-op or always-success default is returned so the caller
// can always use the full DynamicOpDefinition::get overload without branching
// on which slots are set.
// ---------------------------------------------------------------------------

static mlir::OperationName::VerifyInvariantsFn
make_verify_fn(ptr (*fn)(uint64_t)) {
  if (!fn) {
    return [](mlir::Operation*) { return mlir::success(); };
  }
  return [fn](mlir::Operation* op) -> llvm::LogicalResult {
    ptr answer = fn(reinterpret_cast<uint64_t>(op));
    if (isSchemeError(answer)) {
      return op->emitOpError() << schemeErrorText(answer);
    }
    return Sinteger64_value(answer) != 0 ? mlir::success() : mlir::failure();
  };
}

static mlir::OperationName::ParseAssemblyFn make_parse_fn(ptr (*fn)(uint64_t,
                                                                    uint64_t)) {
  return [fn](mlir::OpAsmParser& parser,
              mlir::OperationState& state) -> mlir::ParseResult {
    ptr answer = fn(reinterpret_cast<uint64_t>(&parser),
                    reinterpret_cast<uint64_t>(&state));
    if (isSchemeError(answer)) {
      parser.emitError(parser.getCurrentLocation()) << schemeErrorText(answer);
      return mlir::ParseResult::failure();
    }
    return Sinteger64_value(answer) != 0 ? mlir::ParseResult::success()
                                         : mlir::ParseResult::failure();
  };
}

static mlir::OperationName::PrintAssemblyFn make_print_fn(ptr (*fn)(uint64_t,
                                                                    uint64_t)) {
  return [fn](mlir::Operation* op, mlir::OpAsmPrinter& printer,
              llvm::StringRef defaultDialect) {
    // printAssembly must print the op name first, then the rest.
    llvm::StringRef opName = op->getName().getStringRef();
    if (!defaultDialect.empty() &&
        opName.starts_with((defaultDialect + ".").str())) {
      opName = opName.drop_front(defaultDialect.size() + 1);
    }
    printer << opName;
    ptr answer = fn(reinterpret_cast<uint64_t>(op),
                    reinterpret_cast<uint64_t>(&printer));
    if (isSchemeError(answer)) {
      emitSchemeError(op->getLoc(), answer);
    }
  };
}

static mlir::OperationName::FoldHookFn
make_fold_fn(ptr (*fn)(uint64_t, const void* const*, uint64_t, void*)) {
  if (!fn) {
    return [](mlir::Operation*, llvm::ArrayRef<mlir::Attribute>,
              llvm::SmallVectorImpl<mlir::OpFoldResult>&) {
      return mlir::failure();
    };
  }
  // Scheme callback: (op operand-attributes) -> #f | list of results.
  // operand-attributes has one entry per operand, the constant attribute it
  // folds to or #f (0 here). A result is (value . v) or (attribute . a), as
  // made by fold-value and fold-attribute; Scheme pushes each into `folded`
  // (crest::Fold::addValue / addAttribute). Answering 1 with nothing pushed
  // means the op was folded in place; 0 is no fold, and (who . why) is an
  // error of the Scheme procedure.
  return [fn](mlir::Operation* op, llvm::ArrayRef<mlir::Attribute> operandAttrs,
              llvm::SmallVectorImpl<mlir::OpFoldResult>& results) {
    llvm::SmallVector<const void*, 4> attrs;
    for (mlir::Attribute attr : operandAttrs) {
      attrs.push_back(attr ? attr.getAsOpaquePointer() : nullptr);
    }
    FoldedResults folded;
    ptr answer =
        fn(reinterpret_cast<uint64_t>(op), attrs.data(),
           static_cast<uint64_t>(attrs.size()), static_cast<void*>(&folded));
    if (isSchemeError(answer)) {
      emitSchemeError(op->getLoc(), answer);
      return mlir::failure();
    }
    if (Sinteger64_value(answer) == 0) {
      return mlir::failure();
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
make_canon_fn(ptr (*fn)(uint64_t)) {
  if (!fn) {
    return [](mlir::RewritePatternSet&, mlir::MLIRContext*) {};
  }
  // The callback gets the pattern set as a borrowed shell, valid for the call
  // only.
  return [fn](mlir::RewritePatternSet& patterns, mlir::MLIRContext* ctx) {
    CrestBox<mlir::RewritePatternSet*> shell(&patterns);
    ptr answer = fn(reinterpret_cast<uint64_t>(&shell));
    if (isSchemeError(answer)) {
      emitSchemeError(mlir::UnknownLoc::get(ctx), answer);
    }
  };
}

static mlir::OperationName::PopulateDefaultAttrsFn
make_default_attrs_fn(ptr (*fn)(uint64_t, uint64_t)) {
  if (!fn) {
    return [](const mlir::OperationName&, mlir::NamedAttrList&) {};
  }
  return [fn](const mlir::OperationName& name, mlir::NamedAttrList& attrs) {
    ptr answer = fn(reinterpret_cast<uint64_t>(&name),
                    reinterpret_cast<uint64_t>(&attrs));
    if (isSchemeError(answer)) {
      mlir::OperationName copy = name;
      emitSchemeError(mlir::UnknownLoc::get(copy.getContext()), answer);
    }
  };
}

// ---------------------------------------------------------------------------
// CrestOp::registerInto
// ---------------------------------------------------------------------------

std::string CrestOp::registerInto(mlir::ExtensibleDialect* dialect,
                                  llvm::StringRef op_name, Callbacks cbs,
                                  const LockedSchemeObject& interfaces) {
  auto verify_fn = make_verify_fn(cbs.verify);
  auto verify_region_fn = make_verify_fn(cbs.verify_regions);

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
    def->setParseFn(make_parse_fn(cbs.parse));
  }
  if (cbs.print) {
    def->setPrintFn(make_print_fn(cbs.print));
  }
  if (cbs.fold) {
    def->setFoldHookFn(make_fold_fn(cbs.fold));
  }
  if (cbs.get_canonicalization_patterns) {
    def->setGetCanonicalizationPatternsFn(
        make_canon_fn(cbs.get_canonicalization_patterns));
  }
  if (cbs.populate_default_attrs) {
    def->setPopulateDefaultAttrsFn(
        make_default_attrs_fn(cbs.populate_default_attrs));
  }

  // None of these raises: each answers the text of its error, which the caller
  // returns to Scheme after it has destroyed `def` and unlocked what it holds.
  std::string trait_error = addOpTraits(*def, op_name, cbs.traits);
  if (!trait_error.empty()) {
    return op_name.str() + ": " + trait_error;
  }

  if (std::string error =
          attachInterfaces(*def, interfaces, getAttachInterfaceFns());
      !error.empty()) {
    return error;
  }
  if (std::string error =
          requireCallableOpInterfaceClauses(*def, op_name.str());
      !error.empty()) {
    return error;
  }
  if (std::string error =
          requireArgAndResultAttrsOpInterfaceClauses(*def, op_name.str());
      !error.empty()) {
    return error;
  }
  if (std::string error = requireSymbolOpInterfaceClauses(*def, op_name.str());
      !error.empty()) {
    return error;
  }
  dialect->registerDynamicOp(std::move(def));
  return "";
}

// ---------------------------------------------------------------------------
// Sregister_symbol binding
// ---------------------------------------------------------------------------

// The body of crest::register-dynamic-op!. Answers the text of the error, or ""
// when the op is registered; it never raises, so that the caller can raise
// after the destructors here have run.
static std::string registerOpFromScheme(uint64_t dialect_ptr,
                                        const char* op_name, ptr cbs_ptr,
                                        ptr interfaces_ptr) {
  auto* dialect = reinterpret_cast<mlir::ExtensibleDialect*>(dialect_ptr);
  ptr v = cbs_ptr;
  // Locked before anything that can call Scheme: the garbage collector moves
  // objects.
  LockedSchemeObject interfaces(interfaces_ptr);

  // The slots and the trait names are checked first, so that what follows has
  // nothing left to refuse.
  for (int slot = 0; slot < 7; ++slot) {
    ptr value = Svector_ref(v, slot);
    if (!Sfixnump(value) && !Sbignump(value)) {
      return "callback slot must be the entry point of a callable or 0";
    }
  }
  for (ptr l = Svector_ref(v, 7); !Snullp(l); l = Scdr(l)) {
    for (ptr e = Scar(l); !Snullp(e); e = Scdr(e)) {
      if (!Sstringp(Scar(e))) {
        return "trait names and arguments must be strings";
      }
    }
  }

  auto entry = [&](int slot) -> uint64_t {
    return static_cast<uint64_t>(Sinteger64_value(Svector_ref(v, slot)));
  };

  CrestOp::Callbacks cbs;
  cbs.verify = reinterpret_cast<decltype(cbs.verify)>(entry(0));
  cbs.verify_regions = reinterpret_cast<decltype(cbs.verify_regions)>(entry(1));
  cbs.parse = reinterpret_cast<decltype(cbs.parse)>(entry(2));
  cbs.print = reinterpret_cast<decltype(cbs.print)>(entry(3));
  cbs.fold = reinterpret_cast<decltype(cbs.fold)>(entry(4));
  cbs.get_canonicalization_patterns =
      reinterpret_cast<decltype(cbs.get_canonicalization_patterns)>(entry(5));
  cbs.populate_default_attrs =
      reinterpret_cast<decltype(cbs.populate_default_attrs)>(entry(6));
  auto to_string = [](ptr name) {
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

  return CrestOp::registerInto(dialect, op_name, std::move(cbs), interfaces);
}

void registerCrestDynamicOpBindings() {
  // crest::Fold::addValue (uptr folded) (uptr value)
  // crest::Fold::addAttribute (uptr folded) (uptr attribute)
  //
  // The folder of an op gives each result to the `folded` that C++ passed.
  Sregister_symbol(
      "crest::Fold::addValue",
      (void*)+[](uint64_t folded, uint64_t value) -> ptr {
        reinterpret_cast<FoldedResults*>(folded)->push_back(
            mlir::Value::getFromOpaquePointer(
                reinterpret_cast<const void*>(value)));
        return Svoid;
      });
  Sregister_symbol(
      "crest::Fold::addAttribute",
      (void*)+[](uint64_t folded, uint64_t attribute) -> ptr {
        reinterpret_cast<FoldedResults*>(folded)->push_back(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attribute)));
        return Svoid;
      });

  // crest::register-dynamic-op! (uptr dialect) (string op-name) (scheme-object
  // vector/8) (scheme-object interfaces)
  //
  // Must be called from inside the dialect's :initialize callback. The vector
  // is made once by define-dialect ((crest dialect callbacks)). Slots (0 = use
  // MLIR's default; the others are the entry point of a foreign-callable):
  //   0 verify          (uptr op) → int
  //   1 verify-regions  (uptr op) → int
  //   2 parse           (uptr parser, uptr state) → int   [0 = generic format]
  //   3 print           (uptr op, uptr printer) → void    [0 = generic format]
  //   4 fold            (uptr op, uptr attrs, uptr n, uptr folded) → int
  //   5 get-canonicalization-patterns (uptr pattern-set-shell) → void
  //   6 populate-default-attrs        (uptr op-name, uptr attrs) → void
  //   7 traits                        list of (name arg ...) lists of strings
  //
  // `interfaces` is the list of (TypeID . dispatcher) pairs of the op's
  // :interfaces entries. The dispatchers are only needed while the op is
  // registered, so the list is locked for this call and not kept.
  Sregister_symbol(
      "crest::register-dynamic-op!",
      (void*)+[](uint64_t dialect_ptr, const char* op_name, ptr cbs_ptr,
                 ptr interfaces_ptr) -> ptr {
        // Everything with a destructor lives in
        // registerOpFromScheme, which answers the text of an
        // error; the answer is returned to Scheme after those
        // objects are destroyed and the list is unlocked.
        std::string error =
            registerOpFromScheme(dialect_ptr, op_name, cbs_ptr, interfaces_ptr);
        if (!error.empty()) {
          return scheme_error("crest::register-dynamic-op!", error);
        }
        return Svoid;
      });
}

} // namespace crest

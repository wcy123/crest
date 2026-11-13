/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Traits of Scheme-defined ops — requires LLVM 23+ (DynamicOpTrait / addTrait).

#include "Trait.h"
#include "../Bindings/Interfaces/SideEffectInterfaces.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/Support/raw_ostream.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"
#include <functional>
#include <memory>

namespace crest {

namespace {

// A dynamic trait whose TypeID is the static trait's, with an optional verifier
// of the op
// (`Verify`) or of its regions (`VerifyRegions`).
template <template <typename> class Trait,
          mlir::LogicalResult (*Verify)(mlir::Operation*) = nullptr,
          mlir::LogicalResult (*VerifyRegions)(mlir::Operation*) = nullptr>
class CrestTrait : public mlir::DynamicOpTraitImpl<Trait> {
public:
  mlir::LogicalResult verifyTrait(mlir::Operation* op) const override {
    if constexpr (Verify != nullptr) {
      return Verify(op);
    } else {
      return mlir::success();
    }
  }
  mlir::LogicalResult verifyRegionTrait(mlir::Operation* op) const override {
    if constexpr (VerifyRegions != nullptr) {
      return VerifyRegions(op);
    } else {
      return mlir::success();
    }
  }
};

// MLIR's HasParent is a template on the parent op class, so a dynamic op cannot
// answer hasTrait<HasParent<...>>(); this trait has a TypeID of its own and the
// same verifier message.
template <typename T> class HasParentTag {};

class HasParentTrait : public mlir::DynamicOpTraitImpl<HasParentTag> {
public:
  explicit HasParentTrait(llvm::ArrayRef<std::string> names)
      : names(names.begin(), names.end()) {}
  mlir::LogicalResult verifyTrait(mlir::Operation* op) const override {
    mlir::Operation* parent = op->getParentOp();
    if (parent) {
      for (const std::string& name : names) {
        if (parent->getName().getStringRef() == name) {
          return mlir::success();
        }
      }
    }
    auto diag = op->emitOpError()
                << "expects parent op "
                << (names.size() != 1 ? "to be one of '" : "'");
    llvm::interleave(
        names, diag, [&](const std::string& n) { diag << n; }, "', '");
    return diag << "'";
  }

private:
  std::vector<std::string> names;
};

using Args = llvm::ArrayRef<std::string>;

// What attaching a trait answers: an error message, or that the op has the
// trait already. A second attempt is a status of its own: the caller words it,
// and does not look for it in the text of an error.
struct TraitResult {
  std::string error;
  bool repeated = false;

  static TraitResult added() { return {}; }
  static TraitResult failed(std::string message) {
    return {std::move(message), false};
  }
  static TraitResult alreadyThere() { return {"", true}; }
};

// Attaches the trait to `def`.
using Factory = std::function<TraitResult(mlir::DynamicOpDefinition&,
                                          llvm::StringRef, Args)>;

template <typename T> Factory simple() {
  return [](mlir::DynamicOpDefinition& def, llvm::StringRef,
            Args args) -> TraitResult {
    if (!args.empty()) {
      return TraitResult::failed("takes no arguments");
    }
    return def.addTrait(std::make_unique<T>()) ? TraitResult::added()
                                               : TraitResult::alreadyThere();
  };
}

// `pure` is AlwaysSpeculatable plus NoMemoryEffect. MLIR answers both through
// interfaces (isSpeculatable, isMemoryEffectFree), so they are attached to the
// op next to the trait.
TraitResult addPure(mlir::DynamicOpDefinition& def, llvm::StringRef,
                    Args args) {
  if (!args.empty()) {
    return TraitResult::failed("takes no arguments");
  }
  if (!def.addTrait(
          std::make_unique<
              CrestTrait<mlir::OpTrait::AlwaysSpeculatableImplTrait>>())) {
    return TraitResult::alreadyThere();
  }
  addNoMemoryEffects(def.getInterfaceMap());
  addAlwaysSpeculatable(def.getInterfaceMap());
  return TraitResult::added();
}

// CREST trait name -> how to attach it. One place that pairs a name with the
// static trait whose TypeID `hasTrait` is asked for.
const llvm::StringMap<Factory>& registry() {
  static const llvm::StringMap<Factory> table = {
      {"terminator", simple<mlir::DynamicOpTraits::IsTerminator>()},
      {"no-terminator", simple<mlir::DynamicOpTraits::NoTerminator>()},
      {"commutative", simple<CrestTrait<mlir::OpTrait::IsCommutative>>()},
      {"constant-like", simple<CrestTrait<mlir::OpTrait::ConstantLike>>()},
      {"zero-operands",
       simple<CrestTrait<mlir::OpTrait::ZeroOperands,
                         mlir::OpTrait::impl::verifyZeroOperands>>()},
      {"zero-results",
       simple<CrestTrait<mlir::OpTrait::ZeroResults,
                         mlir::OpTrait::impl::verifyZeroResults>>()},
      {"zero-regions",
       simple<CrestTrait<mlir::OpTrait::ZeroRegions,
                         mlir::OpTrait::impl::verifyZeroRegions>>()},
      {"same-operands-and-result-type",
       simple<
           CrestTrait<mlir::OpTrait::SameOperandsAndResultType,
                      mlir::OpTrait::impl::verifySameOperandsAndResultType>>()},
      {"same-operands-and-result-shape",
       simple<CrestTrait<
           mlir::OpTrait::SameOperandsAndResultShape,
           mlir::OpTrait::impl::verifySameOperandsAndResultShape>>()},
      {"isolated-from-above",
       simple<CrestTrait<mlir::OpTrait::IsIsolatedFromAbove, nullptr,
                         mlir::OpTrait::impl::verifyIsIsolatedFromAbove>>()},
      {"has-parent",
       [](mlir::DynamicOpDefinition& def, llvm::StringRef,
          Args args) -> TraitResult {
         if (args.empty()) {
           return TraitResult::failed("needs at least one parent op name");
         }
         return def.addTrait(std::make_unique<HasParentTrait>(args))
                    ? TraitResult::added()
                    : TraitResult::alreadyThere();
       }},
      {"pure", addPure},
  };
  return table;
}

} // namespace

std::string addOpTraits(mlir::DynamicOpDefinition& def, llvm::StringRef opName,
                        llvm::ArrayRef<TraitSpec> traits) {
  for (const TraitSpec& spec : traits) {
    const std::string& name = spec.front();
    auto it = registry().find(name);
    if (it == registry().end()) {
      return "unknown trait: " + name;
    }
    TraitResult result =
        it->second(def, opName, llvm::ArrayRef<std::string>(spec).drop_front());
    if (result.repeated) {
      return "repeated trait: " + name;
    }
    if (!result.error.empty()) {
      return name + " " + result.error;
    }
  }
  return "";
}

} // namespace crest

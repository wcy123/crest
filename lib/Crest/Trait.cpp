/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Traits of Scheme-defined ops — requires LLVM 23+ (DynamicOpTrait / addTrait).

#include "Trait.h"
#include "llvm/ADT/StringMap.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/OpDefinition.h"
#include <functional>
#include <memory>

namespace crest {

namespace {

// A dynamic trait whose TypeID is the static trait's, with an optional
// verifier.
template <template <typename> class Trait,
          mlir::LogicalResult (*Verify)(mlir::Operation*) = nullptr>
class CrestTrait : public mlir::DynamicOpTraitImpl<Trait> {
public:
  mlir::LogicalResult verifyTrait(mlir::Operation* op) const override {
    if constexpr (Verify != nullptr) {
      return Verify(op);
    } else {
      return mlir::success();
    }
  }
};

using Factory = std::function<std::unique_ptr<mlir::DynamicOpTrait>()>;

template <typename T> Factory factory() {
  return [] { return std::make_unique<T>(); };
}

// CREST trait name -> dynamic trait. One place that pairs a name with the
// static trait whose TypeID `hasTrait` is asked for.
const llvm::StringMap<Factory>& registry() {
  static const llvm::StringMap<Factory> table = {
      {"terminator", factory<mlir::DynamicOpTraits::IsTerminator>()},
      {"no-terminator", factory<mlir::DynamicOpTraits::NoTerminator>()},
      {"commutative", factory<CrestTrait<mlir::OpTrait::IsCommutative>>()},
      {"zero-operands",
       factory<CrestTrait<mlir::OpTrait::ZeroOperands,
                          mlir::OpTrait::impl::verifyZeroOperands>>()},
      {"zero-results",
       factory<CrestTrait<mlir::OpTrait::ZeroResults,
                          mlir::OpTrait::impl::verifyZeroResults>>()},
      {"zero-regions",
       factory<CrestTrait<mlir::OpTrait::ZeroRegions,
                          mlir::OpTrait::impl::verifyZeroRegions>>()},
      {"same-operands-and-result-type",
       factory<
           CrestTrait<mlir::OpTrait::SameOperandsAndResultType,
                      mlir::OpTrait::impl::verifySameOperandsAndResultType>>()},
  };
  return table;
}

} // namespace

std::string addOpTraits(mlir::DynamicOpDefinition& def,
                        llvm::ArrayRef<std::string> names) {
  for (const std::string& name : names) {
    auto it = registry().find(name);
    if (it == registry().end()) {
      return "unknown trait: " + name;
    }
    if (!def.addTrait(it->second())) {
      return "repeated trait: " + name;
    }
  }
  return "";
}

} // namespace crest

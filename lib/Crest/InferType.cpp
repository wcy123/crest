/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// InferTypeOpInterface for Scheme ops — lib/Crest/InferType.cpp
//
// inferReturnTypes is a static interface method: its function pointer in the
// Concept gets no Concept* and no Operation*, so one shared C++ function cannot
// tell which Scheme op it serves. Every op therefore gets a function of its
// own: Scheme makes it with foreign-callable and registers it here by op name.
// The Concept is a heap object in the op's InterfaceMap, so this one model
// type serves all ops and the pointer is filled in per op.

#include "InferType.h"
#include "mlir/IR/Diagnostics.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/Operation.h"
#include "mlir/Interfaces/InferTypeOpInterface.h"
#include <string>
#include <unordered_map>

namespace crest {

namespace {

// The signature differs between LLVM versions (the properties argument is an
// OpaqueProperties before LLVM 23 and a PropertyRef from LLVM 23), so take it
// from the Concept.
using InferFn = decltype(mlir::InferTypeOpInterface::Concept::inferReturnTypes);

struct DynamicInferTypeModel : public mlir::InferTypeOpInterface::Concept {
  using Interface = mlir::InferTypeOpInterface;

  DynamicInferTypeModel()
      : Concept{
            nullptr,
            // Only the ODS-generated verifier calls refineReturnTypes and
            // a dynamic op has no such trait.
            [](mlir::MLIRContext*, std::optional<mlir::Location>,
               mlir::ValueRange, mlir::DictionaryAttr, auto, mlir::RegionRange,
               llvm::SmallVectorImpl<mlir::Type>&) { return mlir::success(); },
            [](mlir::TypeRange lhs, mlir::TypeRange rhs) {
              return lhs == rhs;
            }} {}
};

// Op name -> inferReturnTypes entry registered from Scheme.
std::unordered_map<std::string, InferFn> g_infer_entries;

using CompatibleFn = int (*)(const void* const*, uint64_t, const void* const*,
                             uint64_t);

// Op name -> isCompatibleReturnTypes entry registered from Scheme.
std::unordered_map<std::string, CompatibleFn> g_compatible;

} // namespace

void registerCompatibleReturnTypes(llvm::StringRef opName, void* entry) {
  g_compatible[opName.str()] = reinterpret_cast<CompatibleFn>(entry);
}

void registerInferReturnTypes(llvm::StringRef opName, void* entry) {
  g_infer_entries[opName.str()] = reinterpret_cast<InferFn>(entry);
}

mlir::OperationName::VerifyInvariantsFn
withInferredTypesCheck(mlir::OperationName::VerifyInvariantsFn verify,
                       llvm::StringRef opName) {
  auto it = g_infer_entries.find(opName.str());
  if (it == g_infer_entries.end()) {
    return verify;
  }
  InferFn infer = it->second;
  auto compatibleIt = g_compatible.find(opName.str());
  CompatibleFn compatible =
      compatibleIt == g_compatible.end() ? nullptr : compatibleIt->second;
  return [infer, compatible, verify = std::move(verify)](
             mlir::Operation* op) -> llvm::LogicalResult {
    // The op's own verifier first: its message is the more specific one.
    if (mlir::failed(verify(op))) {
      return mlir::failure();
    }
    // The check of InferTypeOpInterface::verifyInferredResultTypes, which only
    // an op class with the interface as a trait gets.
    llvm::SmallVector<mlir::Type, 4> inferred;
    if (mlir::failed(infer(op->getContext(), op->getLoc(), op->getOperands(),
                           op->getRawDictionaryAttrs(),
                           op->getPropertiesStorage(),
                           mlir::RegionRange(op->getRegions()), inferred))) {
      return op->emitOpError("failed to infer returned types");
    }
    bool isCompatible;
    if (compatible) {
      llvm::SmallVector<const void*, 4> inferredPointers;
      llvm::SmallVector<const void*, 4> actualPointers;
      for (mlir::Type type : inferred) {
        inferredPointers.push_back(type.getAsOpaquePointer());
      }
      for (mlir::Type type : op->getResultTypes()) {
        actualPointers.push_back(type.getAsOpaquePointer());
      }
      isCompatible =
          compatible(inferredPointers.data(), inferredPointers.size(),
                     actualPointers.data(), actualPointers.size()) != 0;
    } else {
      isCompatible =
          mlir::TypeRange(inferred) == mlir::TypeRange(op->getResultTypes());
    }
    if (!isCompatible) {
      return mlir::emitOptionalError(
          op->getLoc(), "'", op->getName().getStringRef(),
          "' op inferred type(s) ", inferred,
          " are incompatible with return type(s) of operation ",
          op->getResultTypes());
    }
    return mlir::success();
  };
}

void attachInferTypeOpInterface(mlir::DynamicOpDefinition& def,
                                llvm::StringRef opName) {
  auto it = g_infer_entries.find(opName.str());
  if (it == g_infer_entries.end()) {
    return;
  }
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  map.insertModels<DynamicInferTypeModel>();
  map.lookup<mlir::InferTypeOpInterface>()->inferReturnTypes = it->second;
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/SymbolTable.h

#include "SymbolTable.h"
#include "../../Crest/Interface.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/SymbolTable.h"

namespace crest {

// ---------------------------------------------------------------------------
// SupportedInterfaces<SymbolOpInterface>::getOrCreateDefaultConcept
//
// Lazily creates the default SymbolOpInterface concept on first call.
// printFunctionOp dispatches to getNameAttr; other methods are stubs.
// ---------------------------------------------------------------------------
template <>
mlir::SymbolOpInterface::Concept*
SupportedInterfaces<mlir::SymbolOpInterface>::getOrCreateDefaultConcept() {
  static mlir::SymbolOpInterface::Concept concept{
      // getNameAttr
      [](const mlir::SymbolOpInterface::Concept*,
         mlir::Operation* op) -> mlir::StringAttr {
        return mlir::cast<mlir::StringAttr>(op->getAttr("sym_name"));
      },
      // setName
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation* op,
         mlir::StringAttr name) { op->setAttr("sym_name", name); },
      // getVisibility
      [](const mlir::SymbolOpInterface::Concept*,
         mlir::Operation*) -> mlir::SymbolTable::Visibility {
        return mlir::SymbolTable::Visibility::Public;
      },
      // isNested / isPrivate / isPublic
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) -> bool {
        return false;
      },
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) -> bool {
        return false;
      },
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) -> bool {
        return true;
      },
      // setVisibility / setNested / setPrivate / setPublic (stubs)
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*,
         mlir::SymbolTable::Visibility) {},
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) {},
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) {},
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) {},
      // getSymbolUses
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*,
         mlir::Operation*) -> std::optional<mlir::SymbolTable::UseRange> {
        return std::nullopt;
      },
      // symbolKnownUseEmpty
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*,
         mlir::Operation*) -> bool { return true; },
      // replaceAllSymbolUses
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*,
         mlir::StringAttr,
         mlir::Operation*) -> llvm::LogicalResult { return mlir::failure(); },
      // isOptionalSymbol / canDiscardOnUseEmpty / isDeclaration
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) -> bool {
        return false;
      },
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) -> bool {
        return false;
      },
      [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) -> bool {
        return false;
      },
  };
  return &concept;
}

// ---------------------------------------------------------------------------
// Sregister_symbol bindings
// ---------------------------------------------------------------------------

void registerIRSymbolTableBindings() {
  // Register the default concept under "." so getRegisteredInterfaceForOp
  // falls back to it for any op that implements SymbolOpInterface without
  // a Scheme override.
  auto no_del = [](void*) {};
  RegisterInterfaceForOp(
      mlir::SymbolOpInterface::getInterfaceID(), ".",
      std::shared_ptr<void>(
          SupportedInterfaces<mlir::SymbolOpInterface>::getOrCreateDefaultConcept(),
          no_del));
}

} // namespace crest

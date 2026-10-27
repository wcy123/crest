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

template <>
mlir::SymbolOpInterface::Concept*
SupportedInterfaces<mlir::SymbolOpInterface>::getOrCreateDefaultConcept() {
  // Thread-safe (C++11): initialised once; registry owns the concept.
  static mlir::SymbolOpInterface::Concept* ptr = [] {
    auto* c = new mlir::SymbolOpInterface::Concept{
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
    RegisterInterfaceForOp(
        mlir::SymbolOpInterface::getInterfaceID(), ".",
        std::shared_ptr<void>(c, [](void* p) {
          delete static_cast<mlir::SymbolOpInterface::Concept*>(p);
        }));
    return c;
  }();
  return ptr;
}

template <>
std::shared_ptr<void>
SupportedInterfaces<mlir::SymbolOpInterface>::CloneConcept(
    const mlir::SymbolOpInterface::Concept* from) {
  return std::shared_ptr<void>(
      new mlir::SymbolOpInterface::Concept(*from), [](void* p) {
        delete static_cast<mlir::SymbolOpInterface::Concept*>(p);
      });
}

void registerIRSymbolTableBindings() {
  // Trigger initialisation -- registration happens inside
  // getOrCreateDefaultConcept() on first call.
  SupportedInterfaces<mlir::SymbolOpInterface>::getOrCreateDefaultConcept();
}

} // namespace crest

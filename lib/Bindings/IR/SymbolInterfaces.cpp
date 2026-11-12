/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/SymbolInterfaces.h

#include "SymbolInterfaces.h"
#include "../../Crest/Interface.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/SymbolTable.h"
#include <memory>
#include <string>

namespace {

// The Concept of SymbolOpInterface for an op, or a Scheme error.
const mlir::SymbolOpInterface::Concept* symbolConcept(uint64_t op_ptr,
                                                      const char* who) {
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  auto* c = crest::lookupConcept<mlir::SymbolOpInterface>(op);
  if (!c) {
    scheme_error(who, "op does not implement SymbolOpInterface:",
                 op->getName().getStringRef());
  }
  return c;
}

mlir::Operation* operation(uint64_t pointer) {
  return reinterpret_cast<mlir::Operation*>(pointer);
}

} // anonymous namespace

namespace crest {

// SymbolOpInterface is a base of FunctionOpInterface, which adds its model so
// that its own can find it. Its slots stay null until the op gives them.
void ensureSymbolOpInterface(mlir::detail::InterfaceMap& map) {
  insertModelOnce<mlir::SymbolOpInterface>(map);
}

// Each method is the callable that Scheme made for its clause, or for the MLIR
// default that the macro writes in Scheme, or the function that CREST ships.
void attachSymbolOpInterface(mlir::DynamicOpDefinition& def,
                             const LockedSchemeObject& dispatcher) {
  mlir::detail::InterfaceMap& map = def.getInterfaceMap();
  ensureSymbolOpInterface(map);
  auto* concept_ = map.lookup<mlir::SymbolOpInterface>();
  installInterfaceEntry(concept_->getNameAttr, dispatcher, "getNameAttr");
  installInterfaceEntry(concept_->setName, dispatcher, "setName");
  installInterfaceEntry(concept_->getVisibility, dispatcher, "getVisibility");
  installInterfaceEntry(concept_->isNested, dispatcher, "isNested");
  installInterfaceEntry(concept_->isPrivate, dispatcher, "isPrivate");
  installInterfaceEntry(concept_->isPublic, dispatcher, "isPublic");
  installInterfaceEntry(concept_->setVisibility, dispatcher, "setVisibility");
  installInterfaceEntry(concept_->setNested, dispatcher, "setNested");
  installInterfaceEntry(concept_->setPrivate, dispatcher, "setPrivate");
  installInterfaceEntry(concept_->setPublic, dispatcher, "setPublic");
  installInterfaceEntry(concept_->getSymbolUses, dispatcher, "getSymbolUses");
  installInterfaceEntry(concept_->symbolKnownUseEmpty, dispatcher,
                        "symbolKnownUseEmpty");
  installInterfaceEntry(concept_->replaceAllSymbolUses, dispatcher,
                        "replaceAllSymbolUses");
  installInterfaceEntry(concept_->isOptionalSymbol, dispatcher,
                        "isOptionalSymbol");
  installInterfaceEntry(concept_->canDiscardOnUseEmpty, dispatcher,
                        "canDiscardOnUseEmpty");
  installInterfaceEntry(concept_->isDeclaration, dispatcher, "isDeclaration");
}

// Another interface adds the model of SymbolOpInterface as its base, so an op
// can have it without having declared it.
std::string requireSymbolOpInterfaceClauses(mlir::DynamicOpDefinition& def,
                                            const std::string& opName) {
  auto* c = def.getInterfaceMap().lookup<mlir::SymbolOpInterface>();
  if (c &&
      (!c->getNameAttr || !c->setName || !c->getVisibility || !c->isNested ||
       !c->isPrivate || !c->isPublic || !c->setVisibility || !c->setNested ||
       !c->setPrivate || !c->setPublic || !c->getSymbolUses ||
       !c->symbolKnownUseEmpty || !c->replaceAllSymbolUses ||
       !c->isOptionalSymbol || !c->canDiscardOnUseEmpty || !c->isDeclaration)) {
    return "FunctionOpInterface extends SymbolOpInterface, so the op has to "
           "declare it, (mlir::SymbolOpInterface) for what MLIR does by "
           "default: " +
           opName;
  }
  return "";
}

void registerIRSymbolInterfacesBindings() {
  // mlir::SymbolOpInterface::getInterfaceID () -> uptr
  //
  // The address that the TypeID of the interface wraps, which C++ turns back
  // with TypeID::getFromOpaquePointer to find how to install the interface.
  Sregister_symbol(
      "mlir::SymbolOpInterface::getInterfaceID", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            mlir::SymbolOpInterface::getInterfaceID().getAsOpaquePointer());
      });

  // The functions that CREST ships for the slots that Scheme cannot write: the
  // address of each, for the MLIR default of the method. They answer what
  // SymbolTable answers (a use range is not something Scheme can build).
  //
  // crest::SymbolOpInterface::getSymbolUses () -> uptr
  // crest::SymbolOpInterface::symbolKnownUseEmpty () -> uptr
  // crest::SymbolOpInterface::replaceAllSymbolUses () -> uptr
  Sregister_symbol(
      "crest::SymbolOpInterface::getSymbolUses", (void*)+[]() -> uint64_t {
        using Concept = mlir::SymbolOpInterface::Concept;
        auto function =
            +[](const Concept*, mlir::Operation* op, mlir::Operation* from)
            -> std::optional<mlir::SymbolTable::UseRange> {
          return mlir::SymbolTable::getSymbolUses(op, from);
        };
        return reinterpret_cast<uint64_t>(function);
      });
  Sregister_symbol(
      "crest::SymbolOpInterface::symbolKnownUseEmpty",
      (void*)+[]() -> uint64_t {
        using Concept = mlir::SymbolOpInterface::Concept;
        auto function = +[](const Concept*, mlir::Operation* op,
                            mlir::Operation* from) -> bool {
          return mlir::SymbolTable::symbolKnownUseEmpty(op, from);
        };
        return reinterpret_cast<uint64_t>(function);
      });
  Sregister_symbol(
      "crest::SymbolOpInterface::replaceAllSymbolUses",
      (void*)+[]() -> uint64_t {
        using Concept = mlir::SymbolOpInterface::Concept;
        auto function =
            +[](const Concept*, mlir::Operation* op, mlir::StringAttr newName,
                mlir::Operation* from) -> llvm::LogicalResult {
          return mlir::SymbolTable::replaceAllSymbolUses(op, newName, from);
        };
        return reinterpret_cast<uint64_t>(function);
      });

  // The methods of the interface on an op, through the Concept of the op.
  Sregister_symbol(
      "mlir::SymbolOpInterface::getNameAttr",
      (void*)+[](uint64_t op) -> uint64_t {
        auto* c = symbolConcept(op, "mlir::SymbolOpInterface::getNameAttr");
        return reinterpret_cast<uint64_t>(
            c->getNameAttr(c, operation(op)).getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::setName",
      (void*)+[](uint64_t op, uint64_t name_ptr) -> void {
        auto* c = symbolConcept(op, "mlir::SymbolOpInterface::setName");
        c->setName(
            c, operation(op),
            mlir::cast<mlir::StringAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(name_ptr))));
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::getVisibility", (void*)+[](uint64_t op) -> int {
        auto* c = symbolConcept(op, "mlir::SymbolOpInterface::getVisibility");
        return static_cast<int>(c->getVisibility(c, operation(op)));
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::isNested", (void*)+[](uint64_t op) -> int {
        auto* c = symbolConcept(op, "mlir::SymbolOpInterface::isNested");
        return c->isNested(c, operation(op)) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::isPrivate", (void*)+[](uint64_t op) -> int {
        auto* c = symbolConcept(op, "mlir::SymbolOpInterface::isPrivate");
        return c->isPrivate(c, operation(op)) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::isPublic", (void*)+[](uint64_t op) -> int {
        auto* c = symbolConcept(op, "mlir::SymbolOpInterface::isPublic");
        return c->isPublic(c, operation(op)) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::setVisibility",
      (void*)+[](uint64_t op, int visibility) -> void {
        auto* c = symbolConcept(op, "mlir::SymbolOpInterface::setVisibility");
        c->setVisibility(
            c, operation(op),
            static_cast<mlir::SymbolTable::Visibility>(visibility));
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::setNested", (void*)+[](uint64_t op) -> void {
        auto* c = symbolConcept(op, "mlir::SymbolOpInterface::setNested");
        c->setNested(c, operation(op));
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::setPrivate", (void*)+[](uint64_t op) -> void {
        auto* c = symbolConcept(op, "mlir::SymbolOpInterface::setPrivate");
        c->setPrivate(c, operation(op));
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::setPublic", (void*)+[](uint64_t op) -> void {
        auto* c = symbolConcept(op, "mlir::SymbolOpInterface::setPublic");
        c->setPublic(c, operation(op));
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::symbolKnownUseEmpty",
      (void*)+[](uint64_t op, uint64_t from) -> int {
        auto* c =
            symbolConcept(op, "mlir::SymbolOpInterface::symbolKnownUseEmpty");
        return c->symbolKnownUseEmpty(c, operation(op), operation(from)) ? 1
                                                                         : 0;
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::replaceAllSymbolUses",
      (void*)+[](uint64_t op, uint64_t new_name, uint64_t from) -> int {
        auto* c =
            symbolConcept(op, "mlir::SymbolOpInterface::replaceAllSymbolUses");
        return mlir::succeeded(c->replaceAllSymbolUses(
                   c, operation(op),
                   mlir::cast<mlir::StringAttr>(
                       mlir::Attribute::getFromOpaquePointer(
                           reinterpret_cast<const void*>(new_name))),
                   operation(from)))
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::isOptionalSymbol",
      (void*)+[](uint64_t op) -> int {
        auto* c =
            symbolConcept(op, "mlir::SymbolOpInterface::isOptionalSymbol");
        return c->isOptionalSymbol(c, operation(op)) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::canDiscardOnUseEmpty",
      (void*)+[](uint64_t op) -> int {
        auto* c =
            symbolConcept(op, "mlir::SymbolOpInterface::canDiscardOnUseEmpty");
        return c->canDiscardOnUseEmpty(c, operation(op)) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir::SymbolOpInterface::isDeclaration", (void*)+[](uint64_t op) -> int {
        auto* c = symbolConcept(op, "mlir::SymbolOpInterface::isDeclaration");
        return c->isDeclaration(c, operation(op)) ? 1 : 0;
      });
}

} // namespace crest

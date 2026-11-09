/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/SymbolInterfaces.h

#include "SymbolInterfaces.h"
#include "../../Crest/Interface.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/SymbolTable.h"
#include <memory>

namespace {
struct SymbolConceptData : public mlir::SymbolOpInterface::Concept {
  SymbolConceptData()
      : mlir::SymbolOpInterface::Concept{
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation* op) -> mlir::StringAttr {
              return mlir::cast<mlir::StringAttr>(op->getAttr("sym_name"));
            },
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation* op,
               mlir::StringAttr name) { op->setAttr("sym_name", name); },
            // Visibility is the "sym_visibility" attribute (public when
            // absent), and a symbol that is not public can be discarded once it
            // has no uses, as MLIR's default implementation of
            // SymbolOpInterface does.
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation* op) -> mlir::SymbolTable::Visibility {
              return mlir::SymbolTable::getSymbolVisibility(op);
            },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation* op) -> bool {
              return mlir::SymbolTable::getSymbolVisibility(op) ==
                     mlir::SymbolTable::Visibility::Nested;
            },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation* op) -> bool {
              return mlir::SymbolTable::getSymbolVisibility(op) ==
                     mlir::SymbolTable::Visibility::Private;
            },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation* op) -> bool {
              return mlir::SymbolTable::getSymbolVisibility(op) ==
                     mlir::SymbolTable::Visibility::Public;
            },
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation* op,
               mlir::SymbolTable::Visibility visibility) {
              mlir::SymbolTable::setSymbolVisibility(op, visibility);
            },
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation* op) {
              mlir::SymbolTable::setSymbolVisibility(
                  op, mlir::SymbolTable::Visibility::Nested);
            },
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation* op) {
              mlir::SymbolTable::setSymbolVisibility(
                  op, mlir::SymbolTable::Visibility::Private);
            },
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation* op) {
              mlir::SymbolTable::setSymbolVisibility(
                  op, mlir::SymbolTable::Visibility::Public);
            },
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation* op,
               mlir::Operation* from)
                -> std::optional<mlir::SymbolTable::UseRange> {
              return mlir::SymbolTable::getSymbolUses(op, from);
            },
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation* op,
               mlir::Operation* from) -> bool {
              return mlir::SymbolTable::symbolKnownUseEmpty(op, from);
            },
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation* op,
               mlir::StringAttr newName,
               mlir::Operation* from) -> llvm::LogicalResult {
              return mlir::SymbolTable::replaceAllSymbolUses(op, newName, from);
            },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation*) -> bool { return false; },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation* op) -> bool {
              return mlir::SymbolTable::getSymbolVisibility(op) !=
                     mlir::SymbolTable::Visibility::Public;
            },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation*) -> bool { return false; },
        } {}
};
} // anonymous namespace

namespace crest {

template <>
mlir::SymbolOpInterface::Concept*
SupportedInterfaces<mlir::SymbolOpInterface>::getOrCreateDefaultConcept() {
  static mlir::SymbolOpInterface::Concept* ptr = [] {
    return getOrCreateDefaultConcept(std::make_unique<SymbolConceptData>());
  }();
  return ptr;
}

template <>
std::shared_ptr<void>
SupportedInterfaces<mlir::SymbolOpInterface>::CloneConcept(
    const mlir::SymbolOpInterface::Concept* from) {
  const auto* src = static_cast<const SymbolConceptData*>(from);
  auto new_data = std::make_unique<SymbolConceptData>(*src);
  return std::shared_ptr<void>(new_data.release(), [](void* p) {
    delete static_cast<SymbolConceptData*>(p);
  });
}

template <>
mlir::SymbolOpInterface::Concept*
SupportedInterfaces<mlir::SymbolOpInterface>::CreateConcept(
    const std::string& op_name) {
  auto data = std::make_unique<SymbolConceptData>();

  SymbolConceptData* raw = data.get();
  RegisterInterfaceForOp(mlir::SymbolOpInterface::getInterfaceID(), op_name,
                         std::shared_ptr<void>(data.release(), [](void* p) {
                           delete static_cast<SymbolConceptData*>(p);
                         }));
  // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
  return reinterpret_cast<mlir::SymbolOpInterface::Concept*>(raw);
}

void registerIRSymbolInterfacesBindings() {
  Sregister_symbol(
      "mlir::SymbolOpInterface", (void*)+[](const char* op_name) {
        crest::SupportedInterfaces<mlir::SymbolOpInterface>::CreateConcept(
            op_name);
      });

  Sregister_symbol(
      "mlir::SymbolOpInterface::getNameAttr",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = static_cast<mlir::SymbolOpInterface::Concept*>(
            LookupInterfaceForOp(mlir::SymbolOpInterface::getInterfaceID(),
                                 op->getName().getStringRef().str()));
        if (!c) {
          scheme_error("mlir::SymbolOpInterface::getNameAttr",
                       "op does not implement SymbolOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        return reinterpret_cast<uint64_t>(
            c->getNameAttr(c, op).getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::SymbolOpInterface::setName",
      (void*)+[](uint64_t op_ptr, uint64_t name_ptr) -> void {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = static_cast<mlir::SymbolOpInterface::Concept*>(
            LookupInterfaceForOp(mlir::SymbolOpInterface::getInterfaceID(),
                                 op->getName().getStringRef().str()));
        if (!c) {
          scheme_error("mlir::SymbolOpInterface::setName",
                       "op does not implement SymbolOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        mlir::StringAttr name =
            mlir::cast<mlir::StringAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(name_ptr)));
        c->setName(c, op, name);
      });
}

} // namespace crest

/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/SymbolInterfaces.h

#include "SymbolInterfaces.h"
#include "../../Crest/Interface.h"
#include "../Support/LockedSchemeObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/SymbolTable.h"
#include <cassert>
#include <memory>

namespace {
struct SymbolConceptData : public mlir::SymbolOpInterface::Concept {
  crest::LockedSchemeObject get_name_attr;
  crest::LockedSchemeObject set_name;
  crest::LockedSchemeObject get_visibility;
  crest::LockedSchemeObject is_nested;
  crest::LockedSchemeObject is_private;
  crest::LockedSchemeObject is_public;
  crest::LockedSchemeObject set_visibility;
  crest::LockedSchemeObject set_nested;
  crest::LockedSchemeObject set_private;
  crest::LockedSchemeObject set_public;
  crest::LockedSchemeObject get_symbol_uses;
  crest::LockedSchemeObject symbol_known_use_empty;
  crest::LockedSchemeObject replace_all_symbol_uses;
  crest::LockedSchemeObject is_optional_symbol;
  crest::LockedSchemeObject can_discard_on_use_empty;
  crest::LockedSchemeObject is_declaration;

  SymbolConceptData()
      : mlir::SymbolOpInterface::Concept{
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation* op) -> mlir::StringAttr {
              return mlir::cast<mlir::StringAttr>(op->getAttr("sym_name"));
            },
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation* op,
               mlir::StringAttr name) { op->setAttr("sym_name", name); },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation*) -> mlir::SymbolTable::Visibility {
              return mlir::SymbolTable::Visibility::Public;
            },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation*) -> bool { return false; },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation*) -> bool { return false; },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation*) -> bool { return true; },
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*,
               mlir::SymbolTable::Visibility) {},
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) {},
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) {},
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*) {},
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*,
               mlir::Operation*) -> std::optional<mlir::SymbolTable::UseRange> {
              return std::nullopt;
            },
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*,
               mlir::Operation*) -> bool { return true; },
            [](const mlir::SymbolOpInterface::Concept*, mlir::Operation*,
               mlir::StringAttr, mlir::Operation*) -> llvm::LogicalResult {
              return mlir::failure();
            },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation*) -> bool { return false; },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation*) -> bool { return false; },
            [](const mlir::SymbolOpInterface::Concept*,
               mlir::Operation*) -> bool { return false; },
        } {
    assert(get_name_attr.get() == Sfalse);
    assert(set_name.get() == Sfalse);
    assert(get_visibility.get() == Sfalse);
    assert(is_nested.get() == Sfalse);
    assert(is_private.get() == Sfalse);
    assert(is_public.get() == Sfalse);
    assert(set_visibility.get() == Sfalse);
    assert(set_nested.get() == Sfalse);
    assert(set_private.get() == Sfalse);
    assert(set_public.get() == Sfalse);
    assert(get_symbol_uses.get() == Sfalse);
    assert(symbol_known_use_empty.get() == Sfalse);
    assert(replace_all_symbol_uses.get() == Sfalse);
    assert(is_optional_symbol.get() == Sfalse);
    assert(can_discard_on_use_empty.get() == Sfalse);
    assert(is_declaration.get() == Sfalse);
  }

  SymbolConceptData(const SymbolConceptData& other)
      : mlir::SymbolOpInterface::Concept(other) {
    assert(other.get_name_attr.get() == Sfalse);
    assert(other.set_name.get() == Sfalse);
    assert(other.get_visibility.get() == Sfalse);
    assert(other.is_nested.get() == Sfalse);
    assert(other.is_private.get() == Sfalse);
    assert(other.is_public.get() == Sfalse);
    assert(other.set_visibility.get() == Sfalse);
    assert(other.set_nested.get() == Sfalse);
    assert(other.set_private.get() == Sfalse);
    assert(other.set_public.get() == Sfalse);
    assert(other.get_symbol_uses.get() == Sfalse);
    assert(other.symbol_known_use_empty.get() == Sfalse);
    assert(other.replace_all_symbol_uses.get() == Sfalse);
    assert(other.is_optional_symbol.get() == Sfalse);
    assert(other.can_discard_on_use_empty.get() == Sfalse);
    assert(other.is_declaration.get() == Sfalse);
  }
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
SupportedInterfaces<mlir::SymbolOpInterface>::CreateConcept(ptr dispatcher) {
  crest::LockedSchemeObject locked_dispatcher(dispatcher);
  std::string op_name = Conversion<ptr, std::string>{}(
      scheme_call(dispatcher, Sstring_to_symbol("operation_name")));

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
      "mlir::SymbolOpInterface", (void*)+[](ptr dispatcher) {
        crest::SupportedInterfaces<mlir::SymbolOpInterface>::CreateConcept(
            dispatcher);
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

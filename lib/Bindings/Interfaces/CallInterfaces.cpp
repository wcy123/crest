/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/CallInterfaces.h

#include "CallInterfaces.h"
#include "../../Crest/Interface.h"
#include "../Support/LockedSchemeObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Region.h"
#include "mlir/IR/Types.h"
#include "mlir/Interfaces/CallInterfaces.h"
#include <cassert>
#include <memory>

// ---------------------------------------------------------------------------
// CallableConceptData — file-local.
// ---------------------------------------------------------------------------
namespace {
struct CallableConceptData : public mlir::CallableOpInterface::Concept {
  crest::LockedSchemeObject get_callable_region;
  crest::LockedSchemeObject get_argument_types;
  crest::LockedSchemeObject get_result_types;

  CallableConceptData()
      : mlir::CallableOpInterface::Concept{
            [](const mlir::CallableOpInterface::Concept*, mlir::Operation* op)
                -> mlir::Region* { return &op->getRegion(0); },
            [](const mlir::CallableOpInterface::Concept*,
               mlir::Operation* op) -> llvm::ArrayRef<mlir::Type> {
              return mlir::cast<mlir::FunctionType>(
                         mlir::cast<mlir::TypeAttr>(
                             op->getAttr("function_type"))
                             .getValue())
                  .getInputs();
            },
            [](const mlir::CallableOpInterface::Concept*,
               mlir::Operation* op) -> llvm::ArrayRef<mlir::Type> {
              return mlir::cast<mlir::FunctionType>(
                         mlir::cast<mlir::TypeAttr>(
                             op->getAttr("function_type"))
                             .getValue())
                  .getResults();
            },
        } {
    assert(get_callable_region.get() == Sfalse);
    assert(get_argument_types.get() == Sfalse);
    assert(get_result_types.get() == Sfalse);
  }

  CallableConceptData(const CallableConceptData& other)
      : mlir::CallableOpInterface::Concept(other) {
    assert(other.get_callable_region.get() == Sfalse);
    assert(other.get_argument_types.get() == Sfalse);
    assert(other.get_result_types.get() == Sfalse);
  }
};

// ---------------------------------------------------------------------------
// ArgAndResultAttrsConceptData — file-local.
// ---------------------------------------------------------------------------
struct ArgAndResultAttrsConceptData
    : public mlir::ArgAndResultAttrsOpInterface::Concept {
  crest::LockedSchemeObject get_arg_attrs_attr;
  crest::LockedSchemeObject get_res_attrs_attr;
  crest::LockedSchemeObject set_arg_attrs_attr;
  crest::LockedSchemeObject set_res_attrs_attr;
  crest::LockedSchemeObject get_arg_attr;
  crest::LockedSchemeObject get_res_attr;

  // printFunctionOp only calls getArgAttrsAttr/getResAttrsAttr; nullptr is
  // safe.
  ArgAndResultAttrsConceptData()
      : mlir::ArgAndResultAttrsOpInterface::Concept{
            [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
               mlir::Operation*) -> mlir::ArrayAttr { return nullptr; },
            [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
               mlir::Operation*) -> mlir::ArrayAttr { return nullptr; },
            [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
               mlir::Operation*, mlir::ArrayAttr) {},
            [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
               mlir::Operation*, mlir::ArrayAttr) {},
            [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
               mlir::Operation*) -> mlir::Attribute { return nullptr; },
            [](const mlir::ArgAndResultAttrsOpInterface::Concept*,
               mlir::Operation*) -> mlir::Attribute { return nullptr; },
        } {
    assert(get_arg_attrs_attr.get() == Sfalse);
    assert(get_res_attrs_attr.get() == Sfalse);
    assert(set_arg_attrs_attr.get() == Sfalse);
    assert(set_res_attrs_attr.get() == Sfalse);
    assert(get_arg_attr.get() == Sfalse);
    assert(get_res_attr.get() == Sfalse);
  }

  ArgAndResultAttrsConceptData(const ArgAndResultAttrsConceptData& other)
      : mlir::ArgAndResultAttrsOpInterface::Concept(other) {
    assert(other.get_arg_attrs_attr.get() == Sfalse);
    assert(other.get_res_attrs_attr.get() == Sfalse);
    assert(other.set_arg_attrs_attr.get() == Sfalse);
    assert(other.set_res_attrs_attr.get() == Sfalse);
    assert(other.get_arg_attr.get() == Sfalse);
    assert(other.get_res_attr.get() == Sfalse);
  }
};
} // anonymous namespace

namespace crest {

template <>
mlir::CallableOpInterface::Concept*
SupportedInterfaces<mlir::CallableOpInterface>::getOrCreateDefaultConcept() {
  static mlir::CallableOpInterface::Concept* ptr = [] {
    return getOrCreateDefaultConcept(std::make_unique<CallableConceptData>());
  }();
  return ptr;
}

template <>
mlir::ArgAndResultAttrsOpInterface::Concept* SupportedInterfaces<
    mlir::ArgAndResultAttrsOpInterface>::getOrCreateDefaultConcept() {
  static mlir::ArgAndResultAttrsOpInterface::Concept* ptr = [] {
    return getOrCreateDefaultConcept(
        std::make_unique<ArgAndResultAttrsConceptData>());
  }();
  return ptr;
}

template <>
std::shared_ptr<void>
SupportedInterfaces<mlir::CallableOpInterface>::CloneConcept(
    const mlir::CallableOpInterface::Concept* from) {
  const auto* src = static_cast<const CallableConceptData*>(from);
  auto new_data = std::make_unique<CallableConceptData>(*src);
  return std::shared_ptr<void>(new_data.release(), [](void* p) {
    delete static_cast<CallableConceptData*>(p);
  });
}

template <>
std::shared_ptr<void>
SupportedInterfaces<mlir::ArgAndResultAttrsOpInterface>::CloneConcept(
    const mlir::ArgAndResultAttrsOpInterface::Concept* from) {
  const auto* src = static_cast<const ArgAndResultAttrsConceptData*>(from);
  auto new_data = std::make_unique<ArgAndResultAttrsConceptData>(*src);
  return std::shared_ptr<void>(new_data.release(), [](void* p) {
    delete static_cast<ArgAndResultAttrsConceptData*>(p);
  });
}

template <>
mlir::CallableOpInterface::Concept*
SupportedInterfaces<mlir::CallableOpInterface>::CreateConcept(ptr dispatcher) {
  crest::LockedSchemeObject locked_dispatcher(dispatcher);
  using Concept = mlir::CallableOpInterface::Concept;
  std::string op_name = Conversion<ptr, std::string>{}(
      scheme_call(dispatcher, Sstring_to_symbol("operation_name")));

  // Lock each returned ptr immediately — each scheme_call is a GC point.
  crest::LockedSchemeObject getCallableRegion(
      scheme_call(dispatcher, Sstring_to_symbol("getCallableRegion")));
  crest::LockedSchemeObject getArgumentTypes(
      scheme_call(dispatcher, Sstring_to_symbol("getArgumentTypes")));
  crest::LockedSchemeObject getResultTypes(
      scheme_call(dispatcher, Sstring_to_symbol("getResultTypes")));

  auto data = std::make_unique<CallableConceptData>();

  if (getCallableRegion.get() != Sfalse) {
    data->get_callable_region =
        crest::LockedSchemeObject(getCallableRegion.get());
    data->getCallableRegion =
        +[](const Concept* self, mlir::Operation* op) -> mlir::Region* {
      const auto* d = static_cast<const CallableConceptData*>(self);
      ptr r = scheme_call(d->get_callable_region.get(),
                          reinterpret_cast<uint64_t>(op));
      return reinterpret_cast<mlir::Region*>(Sunsigned64_value(r));
    };
  }
  if (getArgumentTypes.get() != Sfalse) {
    data->get_argument_types =
        crest::LockedSchemeObject(getArgumentTypes.get());
    data->getArgumentTypes =
        +[](const Concept* self,
            mlir::Operation* op) -> llvm::ArrayRef<mlir::Type> {
      const auto* d = static_cast<const CallableConceptData*>(self);
      (void)d;
      (void)op;
      return {};
    };
  }
  if (getResultTypes.get() != Sfalse) {
    data->get_result_types = crest::LockedSchemeObject(getResultTypes.get());
    data->getResultTypes =
        +[](const Concept* self,
            mlir::Operation* op) -> llvm::ArrayRef<mlir::Type> {
      const auto* d = static_cast<const CallableConceptData*>(self);
      (void)d;
      (void)op;
      return {};
    };
  }

  CallableConceptData* raw = data.get();
  RegisterInterfaceForOp(mlir::CallableOpInterface::getInterfaceID(), op_name,
                         std::shared_ptr<void>(data.release(), [](void* p) {
                           delete static_cast<CallableConceptData*>(p);
                         }));
  // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
  return reinterpret_cast<mlir::CallableOpInterface::Concept*>(raw);
}

template <>
mlir::ArgAndResultAttrsOpInterface::Concept*
SupportedInterfaces<mlir::ArgAndResultAttrsOpInterface>::CreateConcept(
    ptr dispatcher) {
  crest::LockedSchemeObject locked_dispatcher(dispatcher);
  std::string op_name = Conversion<ptr, std::string>{}(
      scheme_call(dispatcher, Sstring_to_symbol("operation_name")));

  auto data = std::make_unique<ArgAndResultAttrsConceptData>();

  ArgAndResultAttrsConceptData* raw = data.get();
  RegisterInterfaceForOp(mlir::ArgAndResultAttrsOpInterface::getInterfaceID(),
                         op_name,
                         std::shared_ptr<void>(data.release(), [](void* p) {
                           delete static_cast<ArgAndResultAttrsConceptData*>(p);
                         }));
  // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
  return reinterpret_cast<mlir::ArgAndResultAttrsOpInterface::Concept*>(raw);
}

void registerInterfacesCallInterfacesBindings() {
  SupportedInterfaces<mlir::CallableOpInterface>::getOrCreateDefaultConcept();
  SupportedInterfaces<
      mlir::ArgAndResultAttrsOpInterface>::getOrCreateDefaultConcept();
  Sregister_symbol(
      "mlir::CallableOpInterface", (void*)+[](ptr dispatcher) {
        crest::SupportedInterfaces<mlir::CallableOpInterface>::CreateConcept(
            dispatcher);
      });
  crest::registerConceptCreatorByName(
      "mlir::CallableOpInterface", +[](ptr d) {
        crest::SupportedInterfaces<mlir::CallableOpInterface>::CreateConcept(d);
      });
  Sregister_symbol(
      "mlir::ArgAndResultAttrsOpInterface", (void*)+[](ptr dispatcher) {
        crest::SupportedInterfaces<
            mlir::ArgAndResultAttrsOpInterface>::CreateConcept(dispatcher);
      });
  crest::registerConceptCreatorByName(
      "mlir::ArgAndResultAttrsOpInterface", +[](ptr d) {
        crest::SupportedInterfaces<
            mlir::ArgAndResultAttrsOpInterface>::CreateConcept(d);
      });

  // ---- CallableOpInterface method bindings --------------------------------

  Sregister_symbol(
      "mlir::CallableOpInterface::getCallableRegion",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = static_cast<mlir::CallableOpInterface::Concept*>(
            LookupInterfaceForOp(mlir::CallableOpInterface::getInterfaceID(),
                                 op->getName().getStringRef().str()));
        if (!c) {
          scheme_error("mlir::CallableOpInterface::getCallableRegion",
                       "op does not implement CallableOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        return reinterpret_cast<uint64_t>(c->getCallableRegion(c, op));
      });

  // ---- ArgAndResultAttrsOpInterface method bindings -----------------------

  Sregister_symbol(
      "mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = static_cast<mlir::ArgAndResultAttrsOpInterface::Concept*>(
            LookupInterfaceForOp(
                mlir::ArgAndResultAttrsOpInterface::getInterfaceID(),
                op->getName().getStringRef().str()));
        if (!c) {
          scheme_error("mlir::ArgAndResultAttrsOpInterface::getArgAttrsAttr",
                       "op does not implement ArgAndResultAttrsOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        mlir::ArrayAttr a = c->getArgAttrsAttr(c, op);
        return a ? reinterpret_cast<uint64_t>(a.getAsOpaquePointer()) : 0;
      });

  Sregister_symbol(
      "mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = static_cast<mlir::ArgAndResultAttrsOpInterface::Concept*>(
            LookupInterfaceForOp(
                mlir::ArgAndResultAttrsOpInterface::getInterfaceID(),
                op->getName().getStringRef().str()));
        if (!c) {
          scheme_error("mlir::ArgAndResultAttrsOpInterface::getResAttrsAttr",
                       "op does not implement ArgAndResultAttrsOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        mlir::ArrayAttr a = c->getResAttrsAttr(c, op);
        return a ? reinterpret_cast<uint64_t>(a.getAsOpaquePointer()) : 0;
      });
}

} // namespace crest

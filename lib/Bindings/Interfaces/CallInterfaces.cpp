/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/CallInterfaces.h

#include "CallInterfaces.h"
#include "../../Crest/Interface.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Region.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/IR/Types.h"
#include "mlir/Interfaces/CallInterfaces.h"
#include <memory>

namespace {
struct CallableConceptData : public mlir::CallableOpInterface::Concept {
  using Concept = mlir::CallableOpInterface::Concept;

  // The entry point of a foreign-callable made in Scheme; nullptr keeps the
  // default implementation, which is the first region of the op.
  uint64_t (*get_callable_region)(uint64_t op) = nullptr;

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
        } {}

  // An entry of 0 leaves the default implementation of the method.
  void install(uint64_t getCallableRegionEntry) {
    if (getCallableRegionEntry != 0) {
      get_callable_region = reinterpret_cast<decltype(get_callable_region)>(
          getCallableRegionEntry);
      getCallableRegion =
          +[](const Concept* self, mlir::Operation* op) -> mlir::Region* {
        const auto* d = static_cast<const CallableConceptData*>(self);
        CREST_REFRESH();
        return reinterpret_cast<mlir::Region*>(
            d->get_callable_region(reinterpret_cast<uint64_t>(op)));
      };
    }
  }
};

// A call op's callee is its "callee" attribute, a symbol reference or (as in
// Toy) a string naming one; its arguments are all of its operands.
struct CallConceptData : public mlir::CallOpInterface::Concept {
  using Concept = mlir::CallOpInterface::Concept;

  CallConceptData()
      : Concept{
            [](const Concept*,
               mlir::Operation* op) -> mlir::CallInterfaceCallable {
              mlir::Attribute callee = op->getAttr("callee");
              if (auto ref =
                      llvm::dyn_cast_or_null<mlir::SymbolRefAttr>(callee)) {
                return ref;
              }
              if (auto name =
                      llvm::dyn_cast_or_null<mlir::StringAttr>(callee)) {
                return mlir::SymbolRefAttr::get(name);
              }
              return mlir::CallInterfaceCallable();
            },
            [](const Concept*, mlir::Operation* op,
               mlir::CallInterfaceCallable callee) {
              auto ref = llvm::dyn_cast_if_present<mlir::SymbolRefAttr>(callee);
              if (!ref) {
                return;
              }
              if (llvm::isa_and_nonnull<mlir::StringAttr>(
                      op->getAttr("callee"))) {
                op->setAttr("callee", ref.getRootReference());
              } else {
                op->setAttr("callee", ref);
              }
            },
            [](const Concept*, mlir::Operation* op)
                -> mlir::Operation::operand_range { return op->getOperands(); },
            [](const Concept*,
               mlir::Operation* op) -> mlir::MutableOperandRange {
              return mlir::MutableOperandRange(op);
            },
            [](const Concept* self, mlir::Operation* op,
               mlir::SymbolTableCollection* table) -> mlir::Operation* {
              mlir::CallInterfaceCallable callable =
                  self->getCallableForCallee(self, op);
              if (auto value =
                      llvm::dyn_cast_if_present<mlir::Value>(callable)) {
                return value.getDefiningOp();
              }
              auto ref =
                  llvm::dyn_cast_if_present<mlir::SymbolRefAttr>(callable);
              if (!ref) {
                return nullptr;
              }
              return table
                         ? table->lookupNearestSymbolFrom(op, ref)
                         : mlir::SymbolTable::lookupNearestSymbolFrom(op, ref);
            },
            [](const Concept* self, mlir::Operation* op) -> mlir::Operation* {
              return self->resolveCallableInTable(self, op, nullptr);
            },
        } {}
};

struct ArgAndResultAttrsConceptData
    : public mlir::ArgAndResultAttrsOpInterface::Concept {
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
        } {}
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
mlir::CallOpInterface::Concept*
SupportedInterfaces<mlir::CallOpInterface>::getOrCreateDefaultConcept() {
  static mlir::CallOpInterface::Concept* ptr = [] {
    return getOrCreateDefaultConcept(std::make_unique<CallConceptData>());
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
std::shared_ptr<void> SupportedInterfaces<mlir::CallOpInterface>::CloneConcept(
    const mlir::CallOpInterface::Concept* from) {
  const auto* src = static_cast<const CallConceptData*>(from);
  return std::shared_ptr<void>(new CallConceptData(*src), [](void* p) {
    delete static_cast<CallConceptData*>(p);
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
SupportedInterfaces<mlir::CallableOpInterface>::CreateConcept(
    const std::string& op_name) {
  auto data = std::make_unique<CallableConceptData>();
  data->implArgAndResultAttrsOpInterface =
      getOrCreateConcept<mlir::ArgAndResultAttrsOpInterface>(op_name);

  CallableConceptData* raw = data.get();
  RegisterInterfaceForOp(mlir::CallableOpInterface::getInterfaceID(), op_name,
                         std::shared_ptr<void>(data.release(), [](void* p) {
                           delete static_cast<CallableConceptData*>(p);
                         }));
  // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
  return reinterpret_cast<mlir::CallableOpInterface::Concept*>(raw);
}

template <>
mlir::CallOpInterface::Concept*
SupportedInterfaces<mlir::CallOpInterface>::CreateConcept(
    const std::string& op_name) {
  auto data = std::make_unique<CallConceptData>();
  data->implArgAndResultAttrsOpInterface =
      getOrCreateConcept<mlir::ArgAndResultAttrsOpInterface>(op_name);

  CallConceptData* raw = data.get();
  RegisterInterfaceForOp(mlir::CallOpInterface::getInterfaceID(), op_name,
                         std::shared_ptr<void>(data.release(), [](void* p) {
                           delete static_cast<CallConceptData*>(p);
                         }));
  // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
  return reinterpret_cast<mlir::CallOpInterface::Concept*>(raw);
}

template <>
mlir::ArgAndResultAttrsOpInterface::Concept*
SupportedInterfaces<mlir::ArgAndResultAttrsOpInterface>::CreateConcept(
    const std::string& op_name) {
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
  SupportedInterfaces<mlir::CallOpInterface>::getOrCreateDefaultConcept();
  SupportedInterfaces<
      mlir::ArgAndResultAttrsOpInterface>::getOrCreateDefaultConcept();
  // mlir::CallableOpInterface (string op-name) (uptr getCallableRegion)
  //
  // The uptr is the entry point of a foreign-callable made in Scheme, or 0 when
  // the op keeps the default implementation.
  Sregister_symbol(
      "mlir::CallableOpInterface",
      (void*)+[](const char* op_name, uint64_t getCallableRegionEntry) {
        auto* data = static_cast<CallableConceptData*>(
            crest::SupportedInterfaces<
                mlir::CallableOpInterface>::CreateConcept(op_name));
        data->install(getCallableRegionEntry);
      });
  Sregister_symbol(
      "mlir::CallOpInterface", (void*)+[](const char* op_name) {
        crest::SupportedInterfaces<mlir::CallOpInterface>::CreateConcept(
            op_name);
      });
  Sregister_symbol(
      "mlir::ArgAndResultAttrsOpInterface", (void*)+[](const char* op_name) {
        crest::SupportedInterfaces<
            mlir::ArgAndResultAttrsOpInterface>::CreateConcept(op_name);
      });

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

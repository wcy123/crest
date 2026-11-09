/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/FunctionInterfaces.h

#include "FunctionInterfaces.h"
#include "../../Crest/Interface.h"
#include "../IR/SymbolInterfaces.h"
#include "../Support/SchemeWrapper.h"
#include "CallInterfaces.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Region.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/Interfaces/CallInterfaces.h"
#include "mlir/Interfaces/FunctionImplementation.h"
#include "mlir/Interfaces/FunctionInterfaces.h"
#include "mlir/Support/InterfaceSupport.h"
#include <memory>

// ---------------------------------------------------------------------------
// FunctionConceptData — file-local; no template, no header.
//
// Inherits from mlir::FunctionOpInterface::Concept so FunctionConceptData*
// is implicitly convertible to Concept*, and static_cast downcasts are valid.
// A method that Scheme implements has the entry point of a foreign-callable in
// the field of its name; the default implementation stays in the Concept
// until then.
// ---------------------------------------------------------------------------
namespace {
// What a Scheme verifyBody or verifyType said: 1 is success. A Scheme error
// makes the callable report its text before it answers 0, so the diagnostic
// can carry it.
std::string g_reported_failure;

llvm::LogicalResult verifyResult(mlir::Operation* op, int answer) {
  if (answer != 0) {
    return mlir::success();
  }
  if (g_reported_failure.empty()) {
    return mlir::failure();
  }
  std::string message = std::move(g_reported_failure);
  g_reported_failure.clear();
  return op->emitOpError() << message;
}

struct FunctionConceptData : public mlir::FunctionOpInterface::Concept {
  using Concept = mlir::FunctionOpInterface::Concept;

  uint64_t (*get_function_type)(uint64_t op) = nullptr;
  void (*set_function_type_attr)(uint64_t op, uint64_t attr) = nullptr;
  uint64_t (*clone_type_with)(uint64_t op, const void* const* inputs,
                              uint64_t input_count, const void* const* results,
                              uint64_t result_count) = nullptr;
  int (*verify_body)(uint64_t op) = nullptr;
  int (*verify_type)(uint64_t op) = nullptr;

  FunctionConceptData()
      : Concept{
            [](const Concept*, mlir::Operation* op) -> mlir::Type {
              return mlir::cast<mlir::TypeAttr>(op->getAttr("function_type"))
                  .getValue();
            },
            [](const Concept*, mlir::Operation* op, mlir::TypeAttr t) {
              op->setAttr("function_type", t);
            },
            [](const Concept*, mlir::Operation* op, mlir::TypeRange inputs,
               mlir::TypeRange results) -> mlir::Type {
              return mlir::FunctionType::get(op->getContext(), inputs, results);
            },
            [](const Concept*, mlir::Operation*) -> llvm::LogicalResult {
              return mlir::success();
            },
            [](const Concept*, mlir::Operation*) -> llvm::LogicalResult {
              return mlir::success();
            },
            crest::SupportedInterfaces<
                mlir::SymbolOpInterface>::getOrCreateDefaultConcept(),
            crest::SupportedInterfaces<mlir::ArgAndResultAttrsOpInterface>::
                getOrCreateDefaultConcept(),
            crest::SupportedInterfaces<
                mlir::CallableOpInterface>::getOrCreateDefaultConcept()} {}

  // An entry of 0 leaves the default implementation of that method.
  void install(uint64_t getFunctionTypeEntry, uint64_t setFunctionTypeAttrEntry,
               uint64_t cloneTypeWithEntry, uint64_t verifyBodyEntry,
               uint64_t verifyTypeEntry) {
    if (getFunctionTypeEntry != 0) {
      get_function_type =
          reinterpret_cast<decltype(get_function_type)>(getFunctionTypeEntry);
      getFunctionType =
          +[](const Concept* self, mlir::Operation* op) -> mlir::Type {
        const auto* d = static_cast<const FunctionConceptData*>(self);
        return mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(
            d->get_function_type(reinterpret_cast<uint64_t>(op))));
      };
    }
    if (setFunctionTypeAttrEntry != 0) {
      set_function_type_attr =
          reinterpret_cast<decltype(set_function_type_attr)>(
              setFunctionTypeAttrEntry);
      setFunctionTypeAttr =
          +[](const Concept* self, mlir::Operation* op, mlir::TypeAttr t) {
            const auto* d = static_cast<const FunctionConceptData*>(self);
            d->set_function_type_attr(
                reinterpret_cast<uint64_t>(op),
                reinterpret_cast<uint64_t>(t.getAsOpaquePointer()));
          };
    }
    if (cloneTypeWithEntry != 0) {
      clone_type_with =
          reinterpret_cast<decltype(clone_type_with)>(cloneTypeWithEntry);
      cloneTypeWith =
          +[](const Concept* self, mlir::Operation* op, mlir::TypeRange inputs,
              mlir::TypeRange results) -> mlir::Type {
        const auto* d = static_cast<const FunctionConceptData*>(self);
        llvm::SmallVector<const void*, 8> inputPointers;
        llvm::SmallVector<const void*, 8> resultPointers;
        for (mlir::Type t : inputs) {
          inputPointers.push_back(t.getAsOpaquePointer());
        }
        for (mlir::Type t : results) {
          resultPointers.push_back(t.getAsOpaquePointer());
        }
        return mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(
            d->clone_type_with(reinterpret_cast<uint64_t>(op),
                               inputPointers.data(), inputPointers.size(),
                               resultPointers.data(), resultPointers.size())));
      };
    }
    if (verifyBodyEntry != 0) {
      verify_body = reinterpret_cast<decltype(verify_body)>(verifyBodyEntry);
      verifyBody =
          +[](const Concept* self, mlir::Operation* op) -> llvm::LogicalResult {
        const auto* d = static_cast<const FunctionConceptData*>(self);
        return verifyResult(op, d->verify_body(reinterpret_cast<uint64_t>(op)));
      };
    }
    if (verifyTypeEntry != 0) {
      verify_type = reinterpret_cast<decltype(verify_type)>(verifyTypeEntry);
      verifyType =
          +[](const Concept* self, mlir::Operation* op) -> llvm::LogicalResult {
        const auto* d = static_cast<const FunctionConceptData*>(self);
        return verifyResult(op, d->verify_type(reinterpret_cast<uint64_t>(op)));
      };
    }
  }
};
} // anonymous namespace

namespace crest {

template <>
mlir::FunctionOpInterface::Concept* crest::SupportedInterfaces<
    mlir::FunctionOpInterface>::getOrCreateDefaultConcept() {
  static mlir::FunctionOpInterface::Concept* ptr = [] {
    return getOrCreateDefaultConcept(std::make_unique<FunctionConceptData>());
  }();
  return ptr;
}
template <>
std::shared_ptr<void>
crest::SupportedInterfaces<mlir::FunctionOpInterface>::CloneConcept(
    const mlir::FunctionOpInterface::Concept* from) {
  const auto* src = static_cast<const FunctionConceptData*>(from);
  auto new_data = std::make_unique<FunctionConceptData>(*src);
  return std::shared_ptr<void>(new_data.release(), [](void* p) {
    delete static_cast<FunctionConceptData*>(p);
  });
}
template <>
mlir::FunctionOpInterface::Concept*
crest::SupportedInterfaces<mlir::FunctionOpInterface>::CreateConcept(
    const std::string& op_name) {
  auto data = std::make_unique<FunctionConceptData>();

  data->implSymbolOpInterface =
      getOrCreateConcept<mlir::SymbolOpInterface>(op_name);
  data->implArgAndResultAttrsOpInterface =
      getOrCreateConcept<mlir::ArgAndResultAttrsOpInterface>(op_name);
  auto* callable = getOrCreateConcept<mlir::CallableOpInterface>(op_name);
  // CallableOpInterface extends ArgAndResultAttrsOpInterface: MLIR's inliner
  // calls through the base, so it must point at this op's concept.
  callable->implArgAndResultAttrsOpInterface =
      data->implArgAndResultAttrsOpInterface;
  data->implCallableOpInterface = callable;

  auto* raw = data.get();
  crest::RegisterInterfaceForOp(
      mlir::FunctionOpInterface::getInterfaceID(), op_name,
      std::shared_ptr<void>(data.release(), [](void* p) {
        delete static_cast<FunctionConceptData*>(p);
      }));
  return raw;
}

void registerInterfacesFunctionInterfacesBindings() {
  // mlir::FunctionOpInterface (string op-name) (uptr getFunctionType)
  //   (uptr setFunctionTypeAttr) (uptr cloneTypeWith) (uptr verifyBody)
  //   (uptr verifyType)
  //
  // Each uptr is the entry point of a foreign-callable made in Scheme, or 0
  // when the op leaves that method to the default implementation.
  Sregister_symbol(
      "mlir::FunctionOpInterface",
      (void*)+[](const char* op_name, uint64_t getFunctionTypeEntry,
                 uint64_t setFunctionTypeAttrEntry, uint64_t cloneTypeWithEntry,
                 uint64_t verifyBodyEntry, uint64_t verifyTypeEntry) {
        auto* data = static_cast<FunctionConceptData*>(
            crest::SupportedInterfaces<
                mlir::FunctionOpInterface>::CreateConcept(op_name));
        data->install(getFunctionTypeEntry, setFunctionTypeAttrEntry,
                      cloneTypeWithEntry, verifyBodyEntry, verifyTypeEntry);
      });

  // crest::FunctionOpInterface::reportFailure (string message)
  //
  // The callable of a verifier calls it with the text of the error its Scheme
  // method raised, before it answers failure, so that the diagnostic shows it.
  Sregister_symbol(
      "crest::FunctionOpInterface::reportFailure",
      (void*)+[](const char* message) -> void {
        g_reported_failure = message;
      });

  // Trigger initialisation of the default concept — registration under "."
  // happens inside
  // SupportedInterfaces<mlir::FunctionOpInterface>::getOrCreateDefaultConcept()
  // on first call.
  SupportedInterfaces<mlir::FunctionOpInterface>::getOrCreateDefaultConcept();

  Sregister_symbol(
      "mlir::function_interface_impl::parseFunctionOp",
      (void*)+[](uint64_t parser_ptr, uint64_t state_ptr) -> int {
        auto* p = reinterpret_cast<mlir::OpAsmParser*>(parser_ptr);
        auto& state = *reinterpret_cast<mlir::OperationState*>(state_ptr);
        auto typeBuilder = [](mlir::Builder& builder,
                              llvm::ArrayRef<mlir::Type> argTypes,
                              llvm::ArrayRef<mlir::Type> resTypes,
                              mlir::function_interface_impl::VariadicFlag,
                              std::string&) -> mlir::Type {
          return builder.getFunctionType(argTypes, resTypes);
        };
        return !mlir::function_interface_impl::parseFunctionOp(
            *p, state, /*allowVariadic=*/false,
            mlir::StringAttr::get(state.getContext(), "function_type"),
            typeBuilder, mlir::StringAttr::get(state.getContext(), "arg_attrs"),
            mlir::StringAttr::get(state.getContext(), "res_attrs"));
      });

  Sregister_symbol(
      "mlir::function_interface_impl::printFunctionOp",
      (void*)+[](uint64_t printer_ptr, uint64_t op_ptr) -> void {
        auto* p = reinterpret_cast<mlir::OpAsmPrinter*>(printer_ptr);
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = static_cast<mlir::FunctionOpInterface::Concept*>(
            LookupInterfaceForOp(mlir::FunctionOpInterface::getInterfaceID(),
                                 op->getName().getStringRef().str()));
        if (!c) {
          c = SupportedInterfaces<
              mlir::FunctionOpInterface>::getOrCreateDefaultConcept();
        }
        mlir::FunctionOpInterface fn(op, c);
        auto* ctx = op->getContext();
        mlir::function_interface_impl::printFunctionOp(
            *p, fn, /*isVariadic=*/false, "function_type",
            mlir::StringAttr::get(ctx, "arg_attrs"),
            mlir::StringAttr::get(ctx, "res_attrs"));
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::getFunctionType",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto name_str = op->getName().getStringRef().str();
        auto* c = static_cast<mlir::FunctionOpInterface::Concept*>(
            LookupInterfaceForOp(mlir::FunctionOpInterface::getInterfaceID(),
                                 name_str));
        if (!c) {
          scheme_error(
              "mlir::FunctionOpInterface::getFunctionType",
              "op does not implement FunctionOpInterface:", name_str.c_str());
        }
        return reinterpret_cast<uint64_t>(
            c->getFunctionType(c, op).getAsOpaquePointer());
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::setFunctionTypeAttr",
      (void*)+[](uint64_t op_ptr, uint64_t attr_ptr) -> void {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = static_cast<mlir::FunctionOpInterface::Concept*>(
            LookupInterfaceForOp(mlir::FunctionOpInterface::getInterfaceID(),
                                 op->getName().getStringRef().str()));
        if (!c) {
          scheme_error("mlir::FunctionOpInterface::setFunctionTypeAttr",
                       "op does not implement FunctionOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        mlir::TypeAttr t =
            mlir::cast<mlir::TypeAttr>(mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attr_ptr)));
        c->setFunctionTypeAttr(c, op, t);
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::verifyBody",
      (void*)+[](uint64_t op_ptr) -> int {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = static_cast<mlir::FunctionOpInterface::Concept*>(
            LookupInterfaceForOp(mlir::FunctionOpInterface::getInterfaceID(),
                                 op->getName().getStringRef().str()));
        if (!c) {
          scheme_error("mlir::FunctionOpInterface::verifyBody",
                       "op does not implement FunctionOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        return mlir::succeeded(c->verifyBody(c, op)) ? 1 : 0;
      });

  Sregister_symbol(
      "mlir::FunctionOpInterface::verifyType",
      (void*)+[](uint64_t op_ptr) -> int {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* c = static_cast<mlir::FunctionOpInterface::Concept*>(
            LookupInterfaceForOp(mlir::FunctionOpInterface::getInterfaceID(),
                                 op->getName().getStringRef().str()));
        if (!c) {
          scheme_error("mlir::FunctionOpInterface::verifyType",
                       "op does not implement FunctionOpInterface:",
                       op->getName().getStringRef().str().c_str());
        }
        return mlir::succeeded(c->verifyType(c, op)) ? 1 : 0;
      });
}

} // namespace crest

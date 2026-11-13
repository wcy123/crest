/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/InferTypeOpInterface.h
//
// InferTypeOpInterface::inferReturnTypes is called through a function pointer
// that gets no Concept* and no Operation*, so Scheme gives every op a function
// of its own (a foreign-callable, see (mlir Interfaces InferTypeOpInterface)),
// which lib/Crest/InferType.cpp installs in the op. That function receives the
// arguments of the C++ call as machine words, in the layout the platform ABI
// gives them, and asks `decode` to rebuild the C++ values as plain Scheme data;
// it calls the op's Scheme procedure itself, inside the callable, and hands the
// answer to `push`. C++ never calls the procedure.

#include "InferTypeOpInterface.h"
#include "../../Crest/InferType.h"
#include "../Support/CrestObject.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "llvm/Config/llvm-config.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/LogicalResult.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/Interfaces/InferTypeOpInterface.h"
#include <cstdint>
#include <cstring>
#include <optional>
#include <string>
#include <type_traits>

namespace crest {

void registerInterfacesInferTypeOpInterfaceBindings() {
  // The Scheme foreign-callable answers with one byte (1 = success, 0 =
  // failure), which is how a LogicalResult is stored: a single bool. Windows
  // makes the callable write that byte into the caller's return box.
  static_assert(sizeof(llvm::LogicalResult) == 1);
  {
    const llvm::LogicalResult success = llvm::success();
    const llvm::LogicalResult failure = llvm::failure();
    unsigned char successByte = 0;
    unsigned char failureByte = 1;
    std::memcpy(&successByte, &success, 1);
    std::memcpy(&failureByte, &failure, 1);
    if (successByte != 1 || failureByte != 0) {
      llvm::report_fatal_error(
          "InferTypeOpInterface: LogicalResult is not stored as 1 / 0");
    }
  }

  // crest::InferTypeOpInterface::decode (uptr w0 ... w10)
  //   -> (context location operands attributes return-types sink)
  //
  // w0 ... w10 are the numbers of MLIR's call to inferReturnTypes(context,
  // location, operands, attributes, properties, regions, result types), as
  // (mlir Interfaces InferTypeOpInterface) receives them. Which number is
  // which depends on the system; see the table there. In short: on Linux a
  // 16-byte object (location, operands, regions, and the properties in
  // LLVM 23) is two numbers, its two halves, so the result types are w9 (w10
  // in LLVM 23); on Windows it is one number, the address of a copy, so the
  // result types are w6. Numbers a layout does not use are ignored.
  //
  // The answer is the list of what the procedure of the op is called with:
  // the context pointer, the location pointer or #f, the list of operand
  // Values, the alist of (name . Attribute), the list of the result Types that
  // the call already holds (refineReturnTypes gets them; the others have none),
  // and, last, the place for the answer, which `push` takes.
  Sregister_symbol(
      "crest::InferTypeOpInterface::decode",
      (void*)+[](uint64_t w0, uint64_t w1, uint64_t w2, uint64_t w3,
                 uint64_t w4, uint64_t w5, uint64_t w6, uint64_t w7,
                 uint64_t w8, uint64_t w9, uint64_t w10) -> ptr {
        static_assert(sizeof(std::optional<mlir::Location>) == 16 &&
                      sizeof(mlir::ValueRange) == 16 &&
                      sizeof(mlir::RegionRange) == 16 &&
                      sizeof(mlir::DictionaryAttr) == 8);
        static_assert(
            std::is_trivially_copyable_v<std::optional<mlir::Location>> &&
            std::is_trivially_copyable_v<mlir::ValueRange> &&
            std::is_trivially_copyable_v<mlir::DictionaryAttr>);

        mlir::MLIRContext* ctx = reinterpret_cast<mlir::MLIRContext*>(w0);
        std::optional<mlir::Location> location;
        mlir::ValueRange operands;
        mlir::DictionaryAttr attributes;
        llvm::SmallVectorImpl<mlir::Type>* result = nullptr;
#ifdef _WIN32
        location = *reinterpret_cast<std::optional<mlir::Location>*>(w1);
        operands = *reinterpret_cast<mlir::ValueRange*>(w2);
        std::memcpy(&attributes, &w3, sizeof(attributes));
        result = reinterpret_cast<llvm::SmallVectorImpl<mlir::Type>*>(w6);
        (void)w4, (void)w5, (void)w7, (void)w8, (void)w9, (void)w10;
#else
        const uint64_t locationWords[2] = {w1, w2};
        const uint64_t operandWords[2] = {w3, w4};
        std::memcpy(&location, locationWords, sizeof(location));
        std::memcpy(&operands, operandWords, sizeof(operands));
        std::memcpy(&attributes, &w5, sizeof(attributes));
    // The properties follow in w6 (and w7 from LLVM 23), then the
    // RegionRange: none of them is needed.
#  if LLVM_VERSION_MAJOR >= 23
        result = reinterpret_cast<llvm::SmallVectorImpl<mlir::Type>*>(w10);
        (void)w6, (void)w7, (void)w8, (void)w9;
#  else
        result = reinterpret_cast<llvm::SmallVectorImpl<mlir::Type>*>(w9);
        (void)w6, (void)w7, (void)w8, (void)w10;
#  endif
#endif

        ptr locationArg = location ? Sunsigned64(reinterpret_cast<uint64_t>(
                                         location->getAsOpaquePointer()))
                                   : Sfalse;
        ptr attributesArg = Snil;
        if (attributes) {
          llvm::ArrayRef<mlir::NamedAttribute> named = attributes.getValue();
          for (size_t i = named.size(); i-- > 0;) {
            ptr name = Sstring(named[i].getName().getValue().str().c_str());
            ptr attr = Sunsigned64(reinterpret_cast<uint64_t>(
                named[i].getValue().getAsOpaquePointer()));
            attributesArg = Scons(Scons(name, attr), attributesArg);
          }
        }
        ptr contextArg = Sunsigned64(reinterpret_cast<uint64_t>(ctx));
        ptr operandsArg = Conversion<mlir::ValueRange, ptr>{}(operands);
        ptr returnTypesArg =
            Conversion<mlir::TypeRange, ptr>{}(mlir::TypeRange(*result));
        ptr sinkArg = Sunsigned64(reinterpret_cast<uint64_t>(result));
        return Scons(
            contextArg,
            Scons(locationArg,
                  Scons(operandsArg,
                        Scons(attributesArg,
                              Scons(returnTypesArg, Scons(sinkArg, Snil))))));
      });

  // crest::InferTypeOpInterface::push (uptr sink) (scheme-object types)
  //   (int refine) -> void
  //
  // The procedure of the op answered the list of result Types: they go to
  // `sink`, the place for the answer that `decode` gave. For refineReturnTypes
  // (`refine`) they replace the types that the call held.
  Sregister_symbol(
      "crest::InferTypeOpInterface::push",
      (void*)+[](uint64_t sink, ptr types, int refine) -> ptr {
        auto* result =
            reinterpret_cast<llvm::SmallVectorImpl<mlir::Type>*>(sink);
        if (refine) {
          result->clear();
        }
        for (; Spairp(types); types = Scdr(types)) {
          result->push_back(mlir::Type::getFromOpaquePointer(
              reinterpret_cast<const void*>(Sunsigned64_value(Scar(types)))));
        }
        return Svoid;
      });

  // mlir::InferTypeOpInterface::getInterfaceID () -> uptr
  //
  // The address that the TypeID of the interface wraps, which C++ turns back
  // with TypeID::getFromOpaquePointer to find how to install the interface.
  Sregister_symbol(
      "mlir::InferTypeOpInterface::getInterfaceID", (void*)+[]() -> ptr {
        return Sunsigned64(reinterpret_cast<uint64_t>(
            mlir::InferTypeOpInterface::getInterfaceID().getAsOpaquePointer()));
      });

  // crest::InferTypeOpInterface::decodeCompatible (uptr w0 w1 w2 w3)
  //   -> (lhs rhs)
  //
  // w0 ... w3 are the numbers of MLIR's call to isCompatibleReturnTypes(
  // TypeRange lhs, TypeRange rhs), as (mlir Interfaces InferTypeOpInterface)
  // receives them: on Linux each 16-byte TypeRange is two numbers (w0 w1, w2
  // w3), on Windows one, the address of a copy (w0, w1). The answer is the two
  // lists of Types.
  Sregister_symbol(
      "crest::InferTypeOpInterface::decodeCompatible",
      (void*)+[](uint64_t w0, uint64_t w1, uint64_t w2, uint64_t w3) -> ptr {
        static_assert(sizeof(mlir::TypeRange) == 16 &&
                      std::is_trivially_copyable_v<mlir::TypeRange>);
        mlir::TypeRange lhs;
        mlir::TypeRange rhs;
#ifdef _WIN32
        lhs = *reinterpret_cast<mlir::TypeRange*>(w0);
        rhs = *reinterpret_cast<mlir::TypeRange*>(w1);
        (void)w2, (void)w3;
#else
        const uint64_t lhsWords[2] = {w0, w1};
        const uint64_t rhsWords[2] = {w2, w3};
        std::memcpy(&lhs, lhsWords, sizeof(lhs));
        std::memcpy(&rhs, rhsWords, sizeof(rhs));
#endif
        ptr lhsList = Conversion<mlir::TypeRange, ptr>{}(lhs);
        ptr rhsList = Conversion<mlir::TypeRange, ptr>{}(rhs);
        return Scons(lhsList, Scons(rhsList, Snil));
      });

  // The result types of the op named by `state`, from the operands, attributes
  // and regions already in it: the list of Types, or #f when the op does not
  // implement InferTypeOpInterface. An OperationState reaches Scheme in two
  // forms (a box from with-OperationState, a raw pointer in a :parse callback),
  // and each has a binding that calls this.
  static const auto infer = [](mlir::OperationState& state) -> ptr {
    std::optional<mlir::RegisteredOperationName> info =
        state.name.getRegisteredInfo();
    auto* model =
        info ? info->getInterface<mlir::InferTypeOpInterface>() : nullptr;
    if (!model || !model->inferReturnTypes) {
      return Sfalse;
    }
    mlir::MLIRContext* ctx = state.getContext();
    llvm::SmallVector<mlir::Type, 4> types;
    if (mlir::failed(model->inferReturnTypes(
            ctx, state.location, state.operands,
            state.attributes.getDictionary(ctx), state.getRawProperties(),
            mlir::RegionRange(state.regions), types))) {
      std::string message =
          "cannot infer the result types of " + state.name.getStringRef().str();
      if (!state.regions.empty()) {
        // An op-form fills the regions after the op exists, as the builders
        // of C++ need the op to own the block: an inference that reads them
        // (scf.if) finds them empty.
        message += ": its regions are still empty when the types are inferred "
                   "(they are filled after the op is created); write -> type";
      }
      return scheme_error("mlir::InferTypeOpInterface::inferReturnTypes",
                          message);
    }
    return Conversion<mlir::TypeRange, ptr>{}(types);
  };

  // mlir::InferTypeOpInterface::inferReturnTypes<OperationState> (uptr state)
  //   state: a CrestBox<OperationState>, as with-OperationState makes
  Sregister_symbol(
      "mlir::InferTypeOpInterface::inferReturnTypes<OperationState>",
      (void*)+[](uint64_t state_ptr) -> ptr {
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::OperationState>::inner(state_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::InferTypeOpInterface::inferReturnTypes<OperationState>",
              "null pointer or not a CrestBox<mlir::OperationState>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        return infer(crest_lookup1);
      });

  // mlir::InferTypeOpInterface::inferReturnTypes<OperationState*> (uptr state)
  //   state: the raw OperationState* of a :parse callback
  Sregister_symbol(
      "mlir::InferTypeOpInterface::inferReturnTypes<OperationState*>",
      (void*)+[](uint64_t state_ptr) -> ptr {
        return infer(*reinterpret_cast<mlir::OperationState*>(state_ptr));
      });
}

} // namespace crest

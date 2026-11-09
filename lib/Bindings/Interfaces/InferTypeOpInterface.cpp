/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Interfaces/InferTypeOpInterface.h
//
// InferTypeOpInterface::inferReturnTypes is called through a function pointer
// that gets no Concept* and no Operation*, so Scheme gives every op a function
// of its own (a foreign-callable, see (mlir Interfaces InferTypeOpInterface))
// and registers its address with registerEntry. That function receives the
// arguments of the C++ call as machine words, in the layout the platform ABI
// gives them, and hands them to `adapt`, which rebuilds the C++ values and
// calls the op's Scheme procedure with plain Scheme data.

#include "InferTypeOpInterface.h"
#include "../../Crest/InferType.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "../Support/XmmGuard.h"
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

namespace {
// The text of the error that a Scheme inferReturnTypes raised, given by its
// callable (reportFailure) before it answers failure, for the message of the
// error that comes back through the function pointer. Cleared when used.
std::string g_reported_failure;
} // namespace

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

  // crest::InferTypeOpInterface::reportFailure (string message)
  //
  // The callable of an op calls it with the text of the error its Scheme
  // method raised, before it answers failure, so that the diagnostic shows it.
  Sregister_symbol(
      "crest::InferTypeOpInterface::reportFailure",
      (void*)+[](const char* message) -> void {
        g_reported_failure = message;
      });

  // crest::InferTypeOpInterface::registerCompatibility (string op-name)
  //                                                    (uptr entry)
  //
  // `entry` is the address of the foreign-callable of the
  // isCompatibleReturnTypes method of the op, which the verifier of the op
  // calls.
  Sregister_symbol(
      "crest::InferTypeOpInterface::registerCompatibility",
      (void*)+[](const char* op_name, uint64_t entry) -> void {
        crest::registerCompatibleReturnTypes(std::string(op_name),
                                             reinterpret_cast<void*>(entry));
      });

  // crest::InferTypeOpInterface::registerEntry (string op-name) (uptr entry)
  //
  // `entry` is the address of the op's foreign-callable.
  Sregister_symbol(
      "crest::InferTypeOpInterface::registerEntry",
      (void*)+[](const char* op_name, uint64_t entry) -> void {
        crest::registerInferReturnTypes(std::string(op_name),
                                        reinterpret_cast<void*>(entry));
      });

  // crest::InferTypeOpInterface::adapt (scheme-object proc) (uptr w0 ... w10)
  //   -> unsigned-8 (1 = success, 0 = failure)
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
  // `proc` is called with (context location operands attributes): the context
  // pointer, the location pointer or #f, the list of operand Values, and the
  // alist of (name . Attribute). It returns the list of result Types, or #f
  // when the types cannot be inferred.
  Sregister_symbol(
      "crest::InferTypeOpInterface::adapt",
      (void*)+[](ptr proc, uint64_t w0, uint64_t w1, uint64_t w2, uint64_t w3,
                 uint64_t w4, uint64_t w5, uint64_t w6, uint64_t w7,
                 uint64_t w8, uint64_t w9, uint64_t w10) -> uint8_t {
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
        ptr types = scheme_call(
            proc, Sunsigned64(reinterpret_cast<uint64_t>(ctx)), locationArg,
            Conversion<mlir::ValueRange, ptr>{}(operands), attributesArg);
        if (types == Sfalse) {
          return 0;
        }
        for (; Spairp(types); types = Scdr(types)) {
          result->push_back(mlir::Type::getFromOpaquePointer(
              reinterpret_cast<const void*>(Sunsigned64_value(Scar(types)))));
        }
        return 1;
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
    g_reported_failure.clear();
    if (mlir::failed(crest::withXmmPreserved([&] {
          return model->inferReturnTypes(
              ctx, state.location, state.operands,
              state.attributes.getDictionary(ctx), state.getRawProperties(),
              mlir::RegionRange(state.regions), types);
        }))) {
      std::string message =
          "cannot infer the result types of " + state.name.getStringRef().str();
      if (!g_reported_failure.empty()) {
        message += ": " + g_reported_failure;
      } else if (!state.regions.empty()) {
        // An op-form fills the regions after the op exists, as the builders
        // of C++ need the op to own the block: an inference that reads them
        // (scf.if) finds them empty.
        message += ": its regions are still empty when the types are inferred "
                   "(they are filled after the op is created); write -> type";
      }
      g_reported_failure.clear();
      scheme_error("mlir::InferTypeOpInterface::inferReturnTypes", message);
    }
    return Conversion<mlir::TypeRange, ptr>{}(types);
  };

  // mlir::InferTypeOpInterface::inferReturnTypes<OperationState> (uptr state)
  //   state: a CrestBox<OperationState>, as with-OperationState makes
  Sregister_symbol(
      "mlir::InferTypeOpInterface::inferReturnTypes<OperationState>",
      (void*)+[](uint64_t state_ptr) -> ptr {
        return infer(crest::CrestBox<mlir::OperationState>::inner(
            state_ptr, "mlir::InferTypeOpInterface::inferReturnTypes"));
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

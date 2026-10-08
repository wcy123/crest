/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/OperationSupport.h

// Thin C wrappers around mlir::OperationState via
// CrestOwned<mlir::OperationState>. The CrestObject deletor handles destruction
// — no explicit ~OperationState binding.

#include "OperationState.h"
#include "../Support/CrestObject.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/OperationSupport.h"

namespace crest {

void registerIROperationStateBindings() {
  Sregister_symbol(
      "mlir::OperationState::create",
      (void*)+[](uint64_t loc_ptr, const char* name) -> uint64_t {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        return reinterpret_cast<uint64_t>(
            new CrestOwned<mlir::OperationState>(loc, name));
      });
  Sregister_symbol(
      "mlir::OperationState::addOperands",
      (void*)+[](uint64_t state_ptr, uint64_t value_ptr) -> void {
        auto* state =
            &reinterpret_cast<CrestOwned<mlir::OperationState>*>(state_ptr)
                 ->inner;
        state->addOperands(mlir::Value::getFromOpaquePointer(
            reinterpret_cast<void*>(value_ptr)));
      });
  Sregister_symbol(
      "mlir::OperationState::addTypes",
      (void*)+[](uint64_t state_ptr, uint64_t type_ptr) -> void {
        auto* state =
            &reinterpret_cast<CrestOwned<mlir::OperationState>*>(state_ptr)
                 ->inner;
        state->addTypes(mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr)));
      });
  Sregister_symbol(
      "mlir::OperationState::addRegion",
      (void*)+[](uint64_t state_ptr) -> void {
        auto* state =
            &reinterpret_cast<CrestOwned<mlir::OperationState>*>(state_ptr)
                 ->inner;
        state->addRegion();
      });
  Sregister_symbol(
      "crest::isa<CrestOwned<mlir::OperationState>>",
      (void*)+[](uint64_t ptr) -> int {
        if (!ptr) {
          return 0;
        }
        return reinterpret_cast<CrestObject*>(ptr)
                       ->isa<CrestOwned<mlir::OperationState>>()
                   ? 1
                   : 0;
      });
}

} // namespace crest

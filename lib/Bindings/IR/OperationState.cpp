/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/OperationSupport.h

// Thin C wrappers around mlir::OperationState (heap-allocated for FFI
// stability). Exposes per-element operand/result/region addition so that
// Scheme side can iterate lists and call through for each element.

#include "OperationState.h"
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
        return reinterpret_cast<uint64_t>(new mlir::OperationState(loc, name));
      });
  Sregister_symbol(
      "mlir::OperationState::addOperands",
      (void*)+[](uint64_t state_ptr, uint64_t value_ptr) -> void {
        reinterpret_cast<mlir::OperationState*>(state_ptr)->addOperands(
            mlir::Value::getFromOpaquePointer(
                reinterpret_cast<void*>(value_ptr)));
      });
  Sregister_symbol(
      "mlir::OperationState::addTypes",
      (void*)+[](uint64_t state_ptr, uint64_t type_ptr) -> void {
        reinterpret_cast<mlir::OperationState*>(state_ptr)->addTypes(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
      });
  Sregister_symbol(
      "mlir::OperationState::addRegion",
      (void*)+[](uint64_t state_ptr) -> void {
        reinterpret_cast<mlir::OperationState*>(state_ptr)->addRegion();
      });
  Sregister_symbol(
      "mlir::OperationState::~OperationState",
      (void*)+[](uint64_t state_ptr) -> void {
        if (!state_ptr) {
          return;
        }
        delete reinterpret_cast<mlir::OperationState*>(state_ptr);
      });
}

} // namespace crest

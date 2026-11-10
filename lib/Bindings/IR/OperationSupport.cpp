/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/OperationSupport.h

// Thin C wrappers around mlir::OperationState via
// CrestBox<mlir::OperationState>. The CrestObject deletor handles destruction
// - no explicit ~OperationState binding.

#include "OperationSupport.h"
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
            new CrestBox<mlir::OperationState>(loc, name));
      });
  Sregister_symbol(
      "mlir::OperationState::addOperands",
      (void*)+[](uint64_t state_ptr, uint64_t value_ptr) -> void {
        crest::CrestBox<mlir::OperationState>::inner(
            state_ptr, "mlir::OperationState::addOperands")
            .addOperands(mlir::Value::getFromOpaquePointer(
                reinterpret_cast<void*>(value_ptr)));
      });
  Sregister_symbol(
      "mlir::OperationState::addTypes",
      (void*)+[](uint64_t state_ptr, uint64_t type_ptr) -> void {
        crest::CrestBox<mlir::OperationState>::inner(
            state_ptr, "mlir::OperationState::addTypes")
            .addTypes(mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
      });
  Sregister_symbol(
      "mlir::OperationState::addRegion",
      (void*)+[](uint64_t state_ptr) -> uint64_t {
        mlir::Region* region = crest::CrestBox<mlir::OperationState>::inner(
                                   state_ptr, "mlir::OperationState::addRegion")
                                   .addRegion();
        return reinterpret_cast<uint64_t>(region);
      });
  Sregister_symbol(
      "mlir::OperationState::addAttribute",
      (void*)+[](uint64_t state_ptr, const char* name,
                 uint64_t attr_ptr) -> void {
        if (!name || !attr_ptr) {
          return;
        }
        crest::CrestBox<mlir::OperationState>::inner(
            state_ptr, "mlir::OperationState::addAttribute")
            .addAttribute(name, mlir::Attribute::getFromOpaquePointer(
                                    reinterpret_cast<const void*>(attr_ptr)));
      });
  Sregister_symbol(
      "crest::isa<CrestBox<mlir::OperationState>>",
      (void*)+[](uint64_t ptr) -> int {
        if (!ptr) {
          return 0;
        }
        return reinterpret_cast<CrestObject*>(ptr)
                       ->isa<CrestBox<mlir::OperationState>>()
                   ? 1
                   : 0;
      });

  // The NamedAttrList of an op that is being created: what the
  // :populate-default-attrs of an op gets. It is the list MLIR is filling,
  // valid for the call. A name is a string; a missing attribute is 0.
  Sregister_symbol(
      "mlir::NamedAttrList::get",
      (void*)+[](uint64_t list_ptr, const char* name) -> uint64_t {
        if (!list_ptr) {
          scheme_error("mlir::NamedAttrList::get",
                       "attribute list pointer is null");
        }
        mlir::Attribute attr =
            reinterpret_cast<mlir::NamedAttrList*>(list_ptr)->get(name);
        return reinterpret_cast<uint64_t>(attr.getAsOpaquePointer());
      });
  Sregister_symbol(
      "mlir::NamedAttrList::append",
      (void*)+[](uint64_t list_ptr, const char* name,
                 uint64_t attr_ptr) -> void {
        if (!list_ptr || !attr_ptr) {
          scheme_error("mlir::NamedAttrList::append",
                       "attribute list or attribute pointer is null");
        }
        reinterpret_cast<mlir::NamedAttrList*>(list_ptr)->append(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
      });
  Sregister_symbol(
      "mlir::NamedAttrList::set",
      (void*)+[](uint64_t list_ptr, const char* name,
                 uint64_t attr_ptr) -> void {
        if (!list_ptr || !attr_ptr) {
          scheme_error("mlir::NamedAttrList::set",
                       "attribute list or attribute pointer is null");
        }
        reinterpret_cast<mlir::NamedAttrList*>(list_ptr)->set(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
      });

  // The OperationName that :populate-default-attrs gets, valid for the call.
  Sregister_symbol(
      "mlir::OperationName::getContext",
      (void*)+[](uint64_t name_ptr) -> uint64_t {
        if (!name_ptr) {
          scheme_error("mlir::OperationName::getContext",
                       "operation name pointer is null");
        }
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::OperationName*>(name_ptr)->getContext());
      });
}

} // namespace crest

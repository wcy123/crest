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
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/OperationSupport.h"

namespace crest {

void registerIROperationStateBindings() {
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-OperationState, which frees it after its body; a box that is never
  // freed leaks.
  Sregister_symbol(
      "mlir::OperationState::create",
      (void*)+[](uint64_t loc_ptr, const char* name) -> ptr {
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        return Sunsigned64(reinterpret_cast<uint64_t>(
            new CrestBox<mlir::OperationState>(loc, name)));
      });
  Sregister_symbol(
      "mlir::OperationState::addOperands",
      (void*)+[](uint64_t state_ptr, uint64_t value_ptr) -> ptr {
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::OperationState>::inner(state_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::OperationState::addOperands",
              "null pointer or not a CrestBox<mlir::OperationState>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.addOperands(mlir::Value::getFromOpaquePointer(
            reinterpret_cast<void*>(value_ptr)));
        return Svoid;
      });
  Sregister_symbol(
      "mlir::OperationState::addTypes",
      (void*)+[](uint64_t state_ptr, uint64_t type_ptr) -> ptr {
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::OperationState>::inner(state_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::OperationState::addTypes",
              "null pointer or not a CrestBox<mlir::OperationState>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.addTypes(mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr)));
        return Svoid;
      });
  Sregister_symbol(
      "mlir::OperationState::addRegion", (void*)+[](uint64_t state_ptr) -> ptr {
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::OperationState>::inner(state_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::OperationState::addRegion",
              "null pointer or not a CrestBox<mlir::OperationState>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        mlir::Region* region = crest_lookup1.addRegion();
        return Sunsigned64(reinterpret_cast<uint64_t>(region));
      });
  Sregister_symbol(
      "mlir::OperationState::addAttribute",
      (void*)+[](uint64_t state_ptr, const char* name,
                 uint64_t attr_ptr) -> ptr {
        if (!name || !attr_ptr) {
          return Svoid;
        }
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::OperationState>::inner(state_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::OperationState::addAttribute",
              "null pointer or not a CrestBox<mlir::OperationState>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.addAttribute(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
        return Svoid;
      });
  Sregister_symbol(
      "crest::isa<CrestBox<mlir::OperationState>>",
      (void*)+[](uint64_t address) -> ptr {
        if (!address) {
          return Sinteger64(0);
        }
        return Sinteger64(reinterpret_cast<CrestObject*>(address)
                                  ->isa<CrestBox<mlir::OperationState>>()
                              ? 1
                              : 0);
      });

  // The NamedAttrList of an op that is being created: what the
  // :populate-default-attrs of an op gets. It is the list MLIR is filling,
  // valid for the call. A name is a string; a missing attribute is 0.
  Sregister_symbol(
      "mlir::NamedAttrList::get",
      (void*)+[](uint64_t list_ptr, const char* name) -> ptr {
        if (!list_ptr) {
          return scheme_error("mlir::NamedAttrList::get",
                              "attribute list pointer is null");
        }
        mlir::Attribute attr =
            reinterpret_cast<mlir::NamedAttrList*>(list_ptr)->get(name);
        return Sunsigned64(
            reinterpret_cast<uint64_t>(attr.getAsOpaquePointer()));
      });
  Sregister_symbol(
      "mlir::NamedAttrList::append",
      (void*)+[](uint64_t list_ptr, const char* name,
                 uint64_t attr_ptr) -> ptr {
        if (!list_ptr || !attr_ptr) {
          return scheme_error("mlir::NamedAttrList::append",
                              "attribute list or attribute pointer is null");
        }
        reinterpret_cast<mlir::NamedAttrList*>(list_ptr)->append(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
        return Svoid;
      });
  Sregister_symbol(
      "mlir::NamedAttrList::set",
      (void*)+[](uint64_t list_ptr, const char* name,
                 uint64_t attr_ptr) -> ptr {
        if (!list_ptr || !attr_ptr) {
          return scheme_error("mlir::NamedAttrList::set",
                              "attribute list or attribute pointer is null");
        }
        reinterpret_cast<mlir::NamedAttrList*>(list_ptr)->set(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
        return Svoid;
      });

  // The OperationName that :populate-default-attrs gets, valid for the call.
  Sregister_symbol(
      "mlir::OperationName::getContext", (void*)+[](uint64_t name_ptr) -> ptr {
        if (!name_ptr) {
          return scheme_error("mlir::OperationName::getContext",
                              "operation name pointer is null");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::OperationName*>(name_ptr)->getContext()));
      });
}

} // namespace crest

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
  register_binding("mlir::OperationState::create",
                   [](uint64_t loc_ptr, const char* name) -> uint64_t {
                     auto loc = mlir::Location::getFromOpaquePointer(
                         reinterpret_cast<const void*>(loc_ptr));
                     return reinterpret_cast<uint64_t>(
                         new CrestBox<mlir::OperationState>(loc, name));
                   });
  register_binding(
      "mlir::OperationState::addOperands",
      [](uint64_t state_ptr, uint64_t value_ptr) -> llvm::Error {
        CREST_TRY(crest_lookup1,
                  crest::CrestBox<mlir::OperationState>::tryInner(
                      state_ptr, "mlir::OperationState::addOperands"));

        crest_lookup1.addOperands(mlir::Value::getFromOpaquePointer(
            reinterpret_cast<void*>(value_ptr)));
        return llvm::Error::success();
      });
  register_binding("mlir::OperationState::addTypes",
                   [](uint64_t state_ptr, uint64_t type_ptr) -> llvm::Error {
                     CREST_TRY(
                         crest_lookup1,
                         crest::CrestBox<mlir::OperationState>::tryInner(
                             state_ptr, "mlir::OperationState::addTypes"));

                     crest_lookup1.addTypes(mlir::Type::getFromOpaquePointer(
                         reinterpret_cast<const void*>(type_ptr)));
                     return llvm::Error::success();
                   });
  register_binding("mlir::OperationState::addRegion",
                   [](uint64_t state_ptr) -> llvm::Expected<uint64_t> {
                     CREST_TRY(
                         crest_lookup1,
                         crest::CrestBox<mlir::OperationState>::tryInner(
                             state_ptr, "mlir::OperationState::addRegion"));

                     mlir::Region* region = crest_lookup1.addRegion();
                     return reinterpret_cast<uint64_t>(region);
                   });
  register_binding("mlir::OperationState::addAttribute",
                   [](uint64_t state_ptr, const char* name,
                      uint64_t attr_ptr) -> llvm::Error {
                     if (!name || !attr_ptr) {
                       return llvm::Error::success();
                     }
                     CREST_TRY(
                         crest_lookup1,
                         crest::CrestBox<mlir::OperationState>::tryInner(
                             state_ptr, "mlir::OperationState::addAttribute"));

                     crest_lookup1.addAttribute(
                         name, mlir::Attribute::getFromOpaquePointer(
                                   reinterpret_cast<const void*>(attr_ptr)));
                     return llvm::Error::success();
                   });
  register_binding("crest::isa<CrestBox<mlir::OperationState>>",
                   [](uint64_t ptr) -> int {
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
  register_binding(
      "mlir::NamedAttrList::get",
      [](uint64_t list_ptr, const char* name) -> llvm::Expected<uint64_t> {
        if (!list_ptr) {
          return fail("mlir::NamedAttrList::get",
                      llvm::Twine("attribute list pointer is null"));
        }
        mlir::Attribute attr =
            reinterpret_cast<mlir::NamedAttrList*>(list_ptr)->get(name);
        return reinterpret_cast<uint64_t>(attr.getAsOpaquePointer());
      });
  register_binding(
      "mlir::NamedAttrList::append",
      [](uint64_t list_ptr, const char* name,
         uint64_t attr_ptr) -> llvm::Error {
        if (!list_ptr || !attr_ptr) {
          return fail(
              "mlir::NamedAttrList::append",
              llvm::Twine("attribute list or attribute pointer is null"));
        }
        reinterpret_cast<mlir::NamedAttrList*>(list_ptr)->append(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
        return llvm::Error::success();
      });
  register_binding(
      "mlir::NamedAttrList::set",
      [](uint64_t list_ptr, const char* name,
         uint64_t attr_ptr) -> llvm::Error {
        if (!list_ptr || !attr_ptr) {
          return fail(
              "mlir::NamedAttrList::set",
              llvm::Twine("attribute list or attribute pointer is null"));
        }
        reinterpret_cast<mlir::NamedAttrList*>(list_ptr)->set(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
        return llvm::Error::success();
      });

  // The OperationName that :populate-default-attrs gets, valid for the call.
  register_binding(
      "mlir::OperationName::getContext",
      [](uint64_t name_ptr) -> llvm::Expected<uint64_t> {
        if (!name_ptr) {
          return fail("mlir::OperationName::getContext",
                      llvm::Twine("operation name pointer is null"));
        }
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::OperationName*>(name_ptr)->getContext());
      });
}

} // namespace crest

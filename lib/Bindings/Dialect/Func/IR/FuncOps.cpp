/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/Func/IR/FuncOps.h

#include "FuncOps.h"
#include "../../../Support/CrestObject.h"
#include "../../../Support/Result.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

void registerDialectFuncIRFuncOpsBindings() {
  // func::FuncOp::create: create a func.func operation via rewriter.
  // (rw-ptr loc-ptr name-str functype-ptr) → Operation* uptr
  Sregister_symbol(
      "mlir::func::FuncOp::create",
      (void*)+[](uint64_t rw_ptr, uint64_t loc_ptr, const char* name,
                 uint64_t functype_ptr) -> ptr {
        auto* rw_box = crest::CrestBox<mlir::RewriterBase*>::inner(rw_ptr);
        if (!rw_box) {
          return scheme_error(
              "mlir::func::FuncOp::create",
              "null pointer or not a CrestBox<mlir::RewriterBase*>");
        }
        auto& rw = *rw_box;
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto functype = mlir::dyn_cast_or_null<mlir::FunctionType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(functype_ptr)));
        if (!functype) {
          return scheme_error("mlir::func::FuncOp::create",
                              "the pointer is null or not a FunctionType");
        }
        auto func = mlir::func::FuncOp::create(rw, loc, name, functype);
        return Sunsigned64(reinterpret_cast<uint64_t>(func.getOperation()));
      });

  // func::ReturnOp::create: create a void func.return via rewriter.
  // (rw-ptr loc-ptr) → Operation* uptr
  Sregister_symbol(
      "mlir::func::ReturnOp::create",
      (void*)+[](uint64_t rw_ptr, uint64_t loc_ptr) -> ptr {
        auto* rw_box = crest::CrestBox<mlir::RewriterBase*>::inner(rw_ptr);
        if (!rw_box) {
          return scheme_error(
              "mlir::func::ReturnOp::create",
              "null pointer or not a CrestBox<mlir::RewriterBase*>");
        }
        auto& rw = *rw_box;
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto ret = mlir::func::ReturnOp::create(rw, loc);
        return Sunsigned64(reinterpret_cast<uint64_t>(ret.getOperation()));
      });

  // func::FuncOp::getBody: get the function body region.
  // (op-ptr) → Region uptr
  Sregister_symbol(
      "mlir::func::FuncOp::getBody", (void*)+[](uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::func::FuncOp::getBody",
                              "operation pointer is null");
        }
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto func = mlir::dyn_cast_or_null<mlir::func::FuncOp>(op);
        if (!func) {
          return scheme_error("mlir::func::FuncOp::getBody",
                              "the pointer is null or not a FuncOp");
        }
        return Sunsigned64(reinterpret_cast<uint64_t>(&func.getBody()));
      });

  // Register FuncDialect into a DialectRegistry.
  Sregister_symbol(
      "mlir::DialectRegistry::insert<mlir::func::FuncDialect>",
      (void*)+[](uint64_t registry_ptr) -> ptr {
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::DialectRegistry>::inner(registry_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::DialectRegistry::insert<mlir::func::FuncDialect>",
              "null pointer or not a CrestBox<mlir::DialectRegistry>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.insert<mlir::func::FuncDialect>();
        return Svoid;
      });
}

} // namespace crest

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
  register_binding("mlir::func::FuncOp::create",
                   [](uint64_t rw_ptr, uint64_t loc_ptr, const char* name,
                      uint64_t functype_ptr) -> llvm::Expected<uint64_t> {
                     CREST_TRY(rw, crest::CrestBox<mlir::RewriterBase*>::inner(
                                       rw_ptr, "mlir::func::FuncOp::create"));
                     auto loc = mlir::Location::getFromOpaquePointer(
                         reinterpret_cast<const void*>(loc_ptr));
                     auto functype = mlir::cast<mlir::FunctionType>(
                         mlir::Type::getFromOpaquePointer(
                             reinterpret_cast<const void*>(functype_ptr)));
                     auto func =
                         mlir::func::FuncOp::create(rw, loc, name, functype);
                     return reinterpret_cast<uint64_t>(func.getOperation());
                   });

  // func::ReturnOp::create: create a void func.return via rewriter.
  // (rw-ptr loc-ptr) → Operation* uptr
  register_binding(
      "mlir::func::ReturnOp::create",
      [](uint64_t rw_ptr, uint64_t loc_ptr) -> llvm::Expected<uint64_t> {
        CREST_TRY(rw, crest::CrestBox<mlir::RewriterBase*>::inner(
                          rw_ptr, "mlir::func::ReturnOp::create"));
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto ret = mlir::func::ReturnOp::create(rw, loc);
        return reinterpret_cast<uint64_t>(ret.getOperation());
      });

  // func::FuncOp::getBody: get the function body region.
  // (op-ptr) → Region uptr
  register_binding("mlir::func::FuncOp::getBody",
                   [](uint64_t op_ptr) -> uint64_t {
                     auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
                     auto func = mlir::cast<mlir::func::FuncOp>(op);
                     return reinterpret_cast<uint64_t>(&func.getBody());
                   });

  // Register FuncDialect into a DialectRegistry.
  register_binding(
      "mlir::DialectRegistry::insert<mlir::func::FuncDialect>",
      [](uint64_t registry_ptr) -> llvm::Error {
        CREST_TRY(
            crest_lookup1,
            crest::CrestBox<mlir::DialectRegistry>::inner(
                registry_ptr,
                "mlir::DialectRegistry::insert<mlir::func::FuncDialect>"));

        crest_lookup1.insert<mlir::func::FuncDialect>();
        return llvm::Error::success();
      });
}

} // namespace crest

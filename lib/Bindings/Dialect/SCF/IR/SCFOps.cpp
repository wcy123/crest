/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Dialect/SCF/IR/SCF.h

#include "SCFOps.h"
#include "../../../Support/SchemeWrapper.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/PatternMatch.h"

namespace crest {

void registerDialectSCFIRSCFOpsBindings() {
  // scf::ForOp::create: create an SCF for loop.
  // (builder-ptr loc-ptr lb-ptr ub-ptr step-ptr) → Operation* uptr
  Sregister_symbol(
      "mlir::scf::ForOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr, uint64_t lb_ptr,
                 uint64_t ub_ptr, uint64_t step_ptr) -> uint64_t {
        auto& builder = *crest::as_raw<mlir::OpBuilder>(
            builder_ptr, "mlir::scf::ForOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        auto lb = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(lb_ptr));
        auto ub = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(ub_ptr));
        auto step = mlir::Value::getFromOpaquePointer(
            reinterpret_cast<const void*>(step_ptr));
        auto loop = mlir::scf::ForOp::create(builder, loc, lb, ub, step);
        return reinterpret_cast<uint64_t>(loop.getOperation());
      });

  // scf::ForOp::getBody: get the loop body block.
  // (op-ptr) → Block* uptr
  Sregister_symbol(
      "mlir::scf::ForOp::getBody", (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto forOp = mlir::cast<mlir::scf::ForOp>(op);
        return reinterpret_cast<uint64_t>(forOp.getBody());
      });

  // scf::ForOp::getInductionVar: get the loop induction variable.
  // (op-ptr) → Value uptr
  Sregister_symbol(
      "mlir::scf::ForOp::getInductionVar",
      (void*)+[](uint64_t op_ptr) -> uint64_t {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto forOp = mlir::cast<mlir::scf::ForOp>(op);
        return reinterpret_cast<uint64_t>(
            forOp.getInductionVar().getAsOpaquePointer());
      });

  // scf::YieldOp::create: create an SCF yield.
  // (builder-ptr loc-ptr) → void
  Sregister_symbol(
      "mlir::scf::YieldOp::create",
      (void*)+[](uint64_t builder_ptr, uint64_t loc_ptr) -> void {
        auto& builder = *crest::as_raw<mlir::OpBuilder>(
            builder_ptr, "mlir::scf::YieldOp::create");
        auto loc = mlir::Location::getFromOpaquePointer(
            reinterpret_cast<const void*>(loc_ptr));
        mlir::scf::YieldOp::create(builder, loc);
      });
}

} // namespace crest

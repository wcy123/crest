/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- crest-opt.cpp - CREST optimizer driver -----------------------------===//
//
// Analogous to mlir-opt. Registers all CREST passes and standard MLIR
// dialects, then delegates to MlirOptMain.
//
//===----------------------------------------------------------------------===//

#include "crest/Passes/Passes.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/Shape/IR/Shape.h"
#include "mlir/Dialect/Tensor/IR/Tensor.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/Tools/mlir-opt/MlirOptMain.h"

int main(int argc, char **argv) {
  mlir::DialectRegistry registry;
  registry.insert<mlir::func::FuncDialect,
                  mlir::shape::ShapeDialect,
                  mlir::tensor::TensorDialect>();
  crest::registerCrestPass();
  return mlir::asMainReturnCode(
      mlir::MlirOptMain(argc, argv, "CREST optimizer driver\n", registry));
}

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Dialect/SCF/IR/SCF.h
(library (mlir Dialect SCF IR SCFOps)
  (export mlir::scf::ForOp::create
          mlir::scf::ForOp::getBody
          mlir::scf::ForOp::getInductionVar
          mlir::scf::YieldOp::create)
  (import (rnrs)
          (mlir Dialect SCF IR SCFOps ffi))

  (define mlir::scf::ForOp::create       %mlir::scf::ForOp::create)
  (define mlir::scf::ForOp::getBody      %mlir::scf::ForOp::getBody)
  (define mlir::scf::ForOp::getInductionVar %mlir::scf::ForOp::getInductionVar)
  (define mlir::scf::YieldOp::create     %mlir::scf::YieldOp::create)

  ) ;; end library (mlir Dialect SCF IR SCFOps)

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Dialect/SCF/IR/SCF.h
(library (mlir Dialect SCF IR SCFOps ffi)
  (export %mlir::scf::ForOp::create
          %mlir::scf::ForOp::getBody
          %mlir::scf::ForOp::getInductionVar
          %mlir::scf::YieldOp::create)
  (import (chezscheme)
          (crest support foreign) (crest support BuilderBinding))

  (define-builder-binding %mlir::scf::ForOp::create
    "mlir::scf::ForOp::create" (uptr uptr uptr uptr uptr) uptr)

  (define %mlir::scf::ForOp::getBody
    (crest-foreign-procedure "mlir::scf::ForOp::getBody" (uptr) uptr))

  (define %mlir::scf::ForOp::getInductionVar
    (crest-foreign-procedure "mlir::scf::ForOp::getInductionVar" (uptr) uptr))

  (define-builder-binding %mlir::scf::YieldOp::create
    "mlir::scf::YieldOp::create" (uptr uptr) void)

  ) ;; end library (mlir Dialect SCF IR SCFOps ffi)

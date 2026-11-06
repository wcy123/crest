#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Dialect/Arith/IR/Arith.h
(library (mlir Dialect Arith IR Arith ffi)
  (export %mlir::arith::AddFOp::create
          %mlir::arith::MulFOp::create
          %mlir::arith::ConstantIndexOp::create
          %mlir::arith::ConstantOp::create<f64>
          %mlir::DialectRegistry::insert<mlir::arith::ArithDialect>)
  (import (chezscheme) (mlir support BuilderBinding))

  (define-builder-binding %mlir::arith::AddFOp::create
    "mlir::arith::AddFOp::create" (uptr uptr uptr uptr) uptr)

  (define-builder-binding %mlir::arith::MulFOp::create
    "mlir::arith::MulFOp::create" (uptr uptr uptr uptr) uptr)

  (define-builder-binding %mlir::arith::ConstantIndexOp::create
    "mlir::arith::ConstantIndexOp::create" (uptr uptr uptr) uptr)

  (define-builder-binding %mlir::arith::ConstantOp::create<f64>
    "mlir::arith::ConstantOp::create<f64>" (uptr uptr uptr) uptr)

  (define %mlir::DialectRegistry::insert<mlir::arith::ArithDialect>
    (foreign-procedure "mlir::DialectRegistry::insert<mlir::arith::ArithDialect>" (uptr) void))

  ) ;; end library (mlir Dialect Arith IR Arith ffi)

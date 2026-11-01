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
          %mlir::arith::ArithDialect)
  (import (chezscheme))

  (define %mlir::arith::AddFOp::create
    (foreign-procedure "mlir::arith::AddFOp::create" (uptr uptr uptr uptr) uptr))

  (define %mlir::arith::MulFOp::create
    (foreign-procedure "mlir::arith::MulFOp::create" (uptr uptr uptr uptr) uptr))

  (define %mlir::arith::ConstantIndexOp::create
    (foreign-procedure "mlir::arith::ConstantIndexOp::create" (uptr uptr uptr) uptr))

  (define %mlir::arith::ConstantOp::create<f64>
    (foreign-procedure "mlir::arith::ConstantOp::create<f64>" (uptr uptr uptr) uptr))

  (define %mlir::arith::ArithDialect
    (foreign-procedure "mlir::arith::ArithDialect" (uptr) void))

  ) ;; end library (mlir Dialect Arith IR Arith ffi)

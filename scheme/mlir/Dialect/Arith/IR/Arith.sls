#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Dialect Arith IR Arith) — Public API for mlir/Dialect/Arith/IR/Arith.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Dialect Arith IR Arith)
  (export mlir::arith::AddFOp::create
          mlir::arith::MulFOp::create
          mlir::arith::ConstantIndexOp::create
          mlir::arith::ConstantOp::create<f64>
          mlir::DialectRegistry::insert<mlir::arith::ArithDialect>)
  (import (rnrs)
          (mlir Dialect Arith IR Arith ffi))

  (define mlir::arith::AddFOp::create          %mlir::arith::AddFOp::create)
  (define mlir::arith::MulFOp::create          %mlir::arith::MulFOp::create)
  (define mlir::arith::ConstantIndexOp::create %mlir::arith::ConstantIndexOp::create)
  (define mlir::arith::ConstantOp::create<f64> %mlir::arith::ConstantOp::create<f64>)
  (define mlir::DialectRegistry::insert<mlir::arith::ArithDialect>            %mlir::DialectRegistry::insert<mlir::arith::ArithDialect>)

  ) ;; end library (mlir Dialect Arith IR Arith)

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Dialect Func IR FuncOps) — Public API for mlir/Dialect/Func/IR/FuncOps.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Dialect Func IR FuncOps)
  (export mlir::func::FuncOp::create
          mlir::func::ReturnOp::create
          mlir::func::FuncOp::getBody
          mlir::DialectRegistry::insert<mlir::func::FuncDialect>)
  (import (rnrs)
          (mlir Dialect Func IR FuncOps ffi))

  (define mlir::func::FuncOp::create   %mlir::func::FuncOp::create)
  (define mlir::func::ReturnOp::create %mlir::func::ReturnOp::create)
  (define mlir::func::FuncOp::getBody  %mlir::func::FuncOp::getBody)
  (define mlir::DialectRegistry::insert<mlir::func::FuncDialect>      %mlir::DialectRegistry::insert<mlir::func::FuncDialect>)

  ) ;; end library (mlir Dialect Func IR FuncOps)

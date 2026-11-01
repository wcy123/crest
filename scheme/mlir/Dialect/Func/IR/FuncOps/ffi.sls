#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/Dialect/Func/IR/FuncOps.h
(library (mlir Dialect Func IR FuncOps ffi)
  (export %mlir::func::FuncOp::create
          %mlir::func::ReturnOp::create
          %mlir::func::FuncOp::getBody
          %mlir::func::FuncDialect)
  (import (chezscheme))

  (define %mlir::func::FuncOp::create
    (foreign-procedure "mlir::func::FuncOp::create" (uptr uptr string uptr) uptr))

  (define %mlir::func::ReturnOp::create
    (foreign-procedure "mlir::func::ReturnOp::create" (uptr uptr) uptr))

  (define %mlir::func::FuncOp::getBody
    (foreign-procedure "mlir::func::FuncOp::getBody" (uptr) uptr))

  (define %mlir::func::FuncDialect
    (foreign-procedure "mlir::func::FuncDialect" (uptr) void))

  ) ;; end library (mlir Dialect Func IR FuncOps ffi)

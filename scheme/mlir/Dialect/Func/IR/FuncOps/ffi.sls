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
          %mlir::DialectRegistry::insert<mlir::func::FuncDialect>)
  (import (chezscheme)
          (mlir support foreign))

  (define %mlir::func::FuncOp::create
    (crest-foreign-procedure "mlir::func::FuncOp::create" (uptr uptr string uptr) uptr))

  (define %mlir::func::ReturnOp::create
    (crest-foreign-procedure "mlir::func::ReturnOp::create" (uptr uptr) uptr))

  (define %mlir::func::FuncOp::getBody
    (crest-foreign-procedure "mlir::func::FuncOp::getBody" (uptr) uptr))

  (define %mlir::DialectRegistry::insert<mlir::func::FuncDialect>
    (crest-foreign-procedure "mlir::DialectRegistry::insert<mlir::func::FuncDialect>" (uptr) void))

  ) ;; end library (mlir Dialect Func IR FuncOps ffi)

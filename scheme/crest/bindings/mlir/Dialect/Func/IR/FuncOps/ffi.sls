#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Dialect Func IR FuncOps ffi) — raw C bindings for func dialect helpers.
;;
;; % prefix = raw C binding. Prefer (mlir Dialect Func IR FuncOps) for normal use.
;;
;; Mirrors mlir/Dialect/Func/IR/FuncOps.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Dialect Func IR FuncOps ffi)
  (export %populate-func-type-conversion-pattern
          %mlir::func::FuncOp::create
          %mlir::func::ReturnOp::create
          %mlir::func::FuncOp::getBody
          %mlir::DialectRegistry::insert<mlir::func::FuncDialect>)
  (import (rnrs)
          (mlir support foreign) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp> —
  ;;        add the standard func.func / func.return type-conversion patterns.
  ;; @param patterns  RewritePatternSet* uptr
  ;; @param converter TypeConverter* uptr
  ;; @return          void
  ;; @see   mlir/Dialect/Func/Transforms/FuncConversions.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %populate-func-type-conversion-pattern
    (crest-foreign-procedure "mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>" (uptr uptr) void))

  (define %mlir::func::FuncOp::create
    (crest-foreign-procedure "mlir::func::FuncOp::create" (uptr uptr string uptr) uptr))

  (define %mlir::func::ReturnOp::create
    (crest-foreign-procedure "mlir::func::ReturnOp::create" (uptr uptr) uptr))

  (define %mlir::func::FuncOp::getBody
    (crest-foreign-procedure "mlir::func::FuncOp::getBody" (uptr) uptr))

  (define %mlir::DialectRegistry::insert<mlir::func::FuncDialect>
    (crest-foreign-procedure "mlir::DialectRegistry::insert<mlir::func::FuncDialect>" (uptr) void))

  ) ;; end library (mlir Dialect Func IR FuncOps ffi)

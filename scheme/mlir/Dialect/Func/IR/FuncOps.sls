#!r6rs
;;===----------------------------------------------------------------------===;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Dialect Func IR FuncOps) — func dialect populate helpers.
;;
;; Mirrors mlir/Dialect/Func/IR/FuncOps.h.
;;
;; Registers conversion patterns that lower func/return ops so that
;; function signatures and return values are updated by the TypeConverter.
;;
;;===----------------------------------------------------------------------===;;
(library (mlir Dialect Func IR FuncOps)
  (export
   mlir-populate-func-type-conversion-pattern)
  (import (rnrs) (mlir Dialect Func IR FuncOps ffi))

  ;; @brief mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp> —
  ;;        add the standard func.func / func.return type-conversion patterns.
  ;; @param patterns  RewritePatternSet* uptr
  ;; @param converter TypeConverter* uptr
  ;; @return          void
  ;; @see   mlir/Dialect/Func/Transforms/FuncConversions.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define mlir-populate-func-type-conversion-pattern
    %populate-func-type-conversion-pattern)

  ) ;; end library (mlir Dialect Func IR FuncOps)

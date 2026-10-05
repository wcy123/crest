#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects func ffi) — raw C bindings for func dialect helpers.
;;
;; % prefix = raw C binding. Prefer (mlir dialects func) for normal use.
;;
;; Mirrors mlir/Dialect/Func/IR/FuncOps.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialects func ffi)
  (export %populate-func-type-conversion-pattern)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp> —
  ;;        add the standard func.func / func.return type-conversion patterns.
  ;; @param patterns  RewritePatternSet* uptr
  ;; @param converter TypeConverter* uptr
  ;; @return          void
  ;; @see   mlir/Dialect/Func/Transforms/FuncConversions.h
  ;; @note  Defined in lib/Bindings/Transforms/DialectConversion.cpp
  (define %populate-func-type-conversion-pattern
    (foreign-procedure "mlir_transforms_dialect_conversion_populate_func_type_conversion" (uptr uptr) void))

) ;; end library (mlir dialects func ffi)

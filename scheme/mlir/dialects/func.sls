#!r6rs
;;===----------------------------------------------------------------------===;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects func) — func dialect populate helpers.
;;
;; Mirrors mlir/Dialect/Func/IR/FuncOps.h.
;;
;; Registers conversion patterns that lower func/return ops so that
;; function signatures and return values are updated by the TypeConverter.
;;
;;===----------------------------------------------------------------------===;;
(library (mlir dialects func)
  (export
    mlir-populate-func-type-conversion-pattern)
  (import (rnrs) (mlir dialects func ffi))

  (define mlir-populate-func-type-conversion-pattern
    %populate-func-type-conversion-pattern)

) ;; end library (mlir dialects func)

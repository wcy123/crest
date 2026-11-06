#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Dialect) — Public API for mlir/IR/Dialect.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Dialect)
  (export mlir::Dialect::materializeConstant)
  (import (rnrs)
          (mlir IR Dialect ffi))

  ;; @brief Dialect::materializeConstant — ask a dialect to create a constant op for a value.
  ;; @param builder  builder shell (any kind)
  ;; @param dialect  mlir::Dialect* uptr, e.g. from mlir::MLIRContext::getOrLoadDialect
  ;; @param value    mlir::Attribute uptr
  ;; @param type     mlir::Type uptr
  ;; @param loc      mlir::Location uptr
  ;; @return         mlir::Operation* uptr, or 0 when the dialect makes none
  (define mlir::Dialect::materializeConstant %mlir::Dialect::materializeConstant)

  ) ;; end library (mlir IR Dialect)

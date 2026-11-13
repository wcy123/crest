#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/IR/Dialect.h
(library (mlir IR Dialect ffi)
  (export %mlir::Dialect::materializeConstant)
  (import (chezscheme) (crest support BuilderBinding))

  (define-builder-binding %mlir::Dialect::materializeConstant
    "mlir::Dialect::materializeConstant" (uptr uptr uptr uptr uptr) uptr)

  ) ;; end library (mlir IR Dialect ffi)

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;; Mirrors mlir/IR/DialectRegistry.h
(library (mlir IR DialectRegistry ffi)
  (export %mlir::DialectRegistry::new
          %mlir::DialectRegistry::insertSchemeDialect
          %mlir::MLIRContext::new/registry
          %CrestObject::delete)
  (import (chezscheme))

  (define %mlir::DialectRegistry::new
    (foreign-procedure "mlir::DialectRegistry::new" () uptr))

  (define %mlir::DialectRegistry::insertSchemeDialect
    (foreign-procedure "mlir::DialectRegistry::insertSchemeDialect"
                       (uptr string string) void))

  (define %mlir::MLIRContext::new/registry
    (foreign-procedure "mlir::MLIRContext::new/registry" (uptr) uptr))

  (define %CrestObject::delete
    (foreign-procedure "CrestObject::delete" (uptr) void))

  ) ;; end library (mlir IR DialectRegistry ffi)

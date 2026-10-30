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
          %mlir::DialectRegistry::insert
          %CrestObject::delete)
  (import (chezscheme))

  (define %mlir::DialectRegistry::new
    (foreign-procedure "mlir::DialectRegistry::new" () uptr))

  (define %mlir::DialectRegistry::insert
    (foreign-procedure "mlir::DialectRegistry::insert"
                       (uptr string string) void))

  (define %CrestObject::delete
    (foreign-procedure "CrestObject::delete" (uptr) void))

  ) ;; end library (mlir IR DialectRegistry ffi)

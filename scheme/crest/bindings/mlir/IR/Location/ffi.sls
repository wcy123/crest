#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Location ffi) — Raw C bindings for mlir::Location constructors.
;;
;; Mirrors mlir/IR/Location.h
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Location ffi)
  (export
    %mlir::UnknownLoc::get
    %mlir::FileLineColLoc::get)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %mlir::UnknownLoc::get
    (foreign-procedure "mlir::UnknownLoc::get" (uptr) uptr))

  (define %mlir::FileLineColLoc::get
    (foreign-procedure "mlir::FileLineColLoc::get" (uptr string unsigned-32 unsigned-32) uptr))

  ) ;; end library (mlir IR Location ffi)

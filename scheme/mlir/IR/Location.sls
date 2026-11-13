#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Location) — Location constructors.
;;
;; Mirrors mlir/IR/Location.h
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Location)
  (export
    mlir::UnknownLoc::get
    mlir::FileLineColLoc::get)
  (import (rnrs)
          (only (mlir IR MLIRContext) current-MLIRContext)
          (mlir IR Location ffi))

  ;; @brief mlir::UnknownLoc::get — create an unknown/unspecified location.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @return     mlir::Location uptr
  ;; @see        mlir/IR/Location.h
  (define mlir::UnknownLoc::get
    (case-lambda
     [()    (%mlir::UnknownLoc::get (current-MLIRContext))]
     [(ctx) (%mlir::UnknownLoc::get ctx)]))

  ;; @brief mlir::FileLineColLoc::get — create a file/line/column source location.
  ;; @param ctx       MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @param filename  string — source file name
  ;; @param line      exact integer — 1-based line number
  ;; @param col       exact integer — 1-based column number
  ;; @return          mlir::Location uptr
  ;; @see             mlir/IR/Location.h
  (define mlir::FileLineColLoc::get
    (case-lambda
     [(filename line col)
      (%mlir::FileLineColLoc::get (current-MLIRContext) filename line col)]
     [(ctx filename line col)
      (%mlir::FileLineColLoc::get ctx filename line col)]))

  ) ;; end library (mlir IR Location)

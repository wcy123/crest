#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialect shape ir ffi) — raw C bindings for mlir/Dialect/Shape/IR/Shape.h.
;;
;; % prefix = raw C binding. Prefer (mlir dialect shape ir) for normal use.
;;
;; Mirrors mlir/Dialect/Shape/IR/Shape.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialect shape ir ffi)
  (export %mlir::shape::ShapeType::get %mlir::shape::SizeType::get %mlir::shape::WitnessType::get)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::shape::ShapeType::get — get the shape dialect's Shape type.
  ;; @param ctx  MLIRContext* uptr
  ;; @return     ShapeType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  (define %mlir::shape::ShapeType::get
    (foreign-procedure "mlir::shape::ShapeType::get" (uptr) uptr))

  ;; @brief mlir::shape::SizeType::get — get the shape dialect's Size type.
  ;; @param ctx  MLIRContext* uptr
  ;; @return     SizeType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  (define %mlir::shape::SizeType::get
    (foreign-procedure "mlir::shape::SizeType::get" (uptr) uptr))

  ;; @brief mlir::shape::WitnessType::get — get the shape dialect's Witness type.
  ;; @param ctx  MLIRContext* uptr
  ;; @return     WitnessType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  (define %mlir::shape::WitnessType::get
    (foreign-procedure "mlir::shape::WitnessType::get" (uptr) uptr))

) ;; end library (mlir dialect shape ir ffi)

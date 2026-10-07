#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Dialect Shape IR Shape) — Shape dialect type factories.
;;
;; Mirrors mlir/Dialect/Shape/IR/Shape.h.
;; Imports raw C bindings from (mlir Dialect Shape IR Shape ffi) and re-exports
;; under clean names. Add Scheme-level helpers here as needed.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Dialect Shape IR Shape)
  (export mlir::shape::ShapeType::get mlir::shape::SizeType::get mlir::shape::WitnessType::get)
  (import (rnrs)
          (mlir Dialect Shape IR Shape ffi)
          (mlir IR MLIRContext))

  ;; @brief mlir::shape::ShapeType::get — get the shape dialect's Shape type.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @return     ShapeType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  (define-ctx-optional mlir::shape::ShapeType::get %mlir::shape::ShapeType::get)

  ;; @brief mlir::shape::SizeType::get — get the shape dialect's Size type.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @return     SizeType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  (define-ctx-optional mlir::shape::SizeType::get %mlir::shape::SizeType::get)

  ;; @brief mlir::shape::WitnessType::get — get the shape dialect's Witness type.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-MLIRContext)
  ;; @return     WitnessType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  (define-ctx-optional mlir::shape::WitnessType::get %mlir::shape::WitnessType::get)

  ) ;; end library (mlir Dialect Shape IR Shape)

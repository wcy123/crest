#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialect shape ir) — Shape dialect type factories.
;;
;; Mirrors mlir/Dialect/Shape/IR/Shape.h.
;; Imports raw C bindings from (mlir dialect shape ir ffi) and re-exports
;; under clean names. Add Scheme-level helpers here as needed.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialect shape ir)
  (export mlir::shape::ShapeType::get mlir::shape::SizeType::get mlir::shape::WitnessType::get)
  (import (rnrs)
          (mlir dialect shape ir ffi)
          (mlir ir mlir-context))

  ;; @brief mlir::shape::ShapeType::get — get the shape dialect's Shape type.
  ;; @return     ShapeType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Uses current-mlir-context; defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  ;; @brief mlir::shape::ShapeType::get — get the shape dialect's Shape type.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-mlir-context)
  ;; @return     ShapeType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  (define mlir::shape::ShapeType::get
    (case-lambda
      [()    (%mlir::shape::ShapeType::get (current-mlir-context))]
      [(ctx) (%mlir::shape::ShapeType::get ctx)]))

  ;; @brief mlir::shape::SizeType::get — get the shape dialect's Size type.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-mlir-context)
  ;; @return     SizeType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  (define mlir::shape::SizeType::get
    (case-lambda
      [()    (%mlir::shape::SizeType::get (current-mlir-context))]
      [(ctx) (%mlir::shape::SizeType::get ctx)]))

  ;; @brief mlir::shape::WitnessType::get — get the shape dialect's Witness type.
  ;; @param ctx  MLIRContext* uptr (optional; defaults to current-mlir-context)
  ;; @return     WitnessType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  (define mlir::shape::WitnessType::get
    (case-lambda
      [()    (%mlir::shape::WitnessType::get (current-mlir-context))]
      [(ctx) (%mlir::shape::WitnessType::get ctx)]))

) ;; end library (mlir dialect shape ir)

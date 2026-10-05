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
  (export shape-type-get size-type-get witness-type-get)
  (import (rnrs) (mlir dialect shape ir ffi))

  ;; @brief mlir::shape::ShapeType::get — get the shape dialect's Shape type.
  ;; @param ctx  MLIRContext* uptr
  ;; @return     ShapeType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  (define shape-type-get   %shape-type-get)

  ;; @brief mlir::shape::SizeType::get — get the shape dialect's Size type.
  ;; @param ctx  MLIRContext* uptr
  ;; @return     SizeType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  (define size-type-get    %size-type-get)

  ;; @brief mlir::shape::WitnessType::get — get the shape dialect's Witness type.
  ;; @param ctx  MLIRContext* uptr
  ;; @return     WitnessType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Defined in lib/Bindings/Dialect/Shape/IR/Shape.cpp
  (define witness-type-get %witness-type-get)

) ;; end library (mlir dialect shape ir)

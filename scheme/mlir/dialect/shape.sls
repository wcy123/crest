#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialect shape) — backward-compat shim.
;; Canonical module is (mlir dialect shape ir).
;;
;; This file is a backward-compatibility shim; it has no direct MLIR header
;; of its own.  See (mlir dialect shape ir) which mirrors
;; mlir/Dialect/Shape/IR/Shape.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialect shape)
  ;; @brief mlir::shape::ShapeType::get — get the shape dialect's Shape type.
  ;; @param ctx  MLIRContext* uptr
  ;; @return     ShapeType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Re-exported from (mlir dialect shape ir) for backward compatibility.
  ;;
  ;; @brief mlir::shape::SizeType::get — get the shape dialect's Size type.
  ;; @param ctx  MLIRContext* uptr
  ;; @return     SizeType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Re-exported from (mlir dialect shape ir) for backward compatibility.
  ;;
  ;; @brief mlir::shape::WitnessType::get — get the shape dialect's Witness type.
  ;; @param ctx  MLIRContext* uptr
  ;; @return     WitnessType opaque pointer uptr
  ;; @see        mlir/Dialect/Shape/IR/Shape.h
  ;; @note       Re-exported from (mlir dialect shape ir) for backward compatibility.
  (export mlir::shape::ShapeType::get mlir::shape::SizeType::get mlir::shape::WitnessType::get)
  (import (rnrs) (mlir dialect shape ir))

) ;; end library (mlir dialect shape)

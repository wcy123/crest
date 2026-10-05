#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir type) — mlir::Type base class bindings.
;;
;; Mirrors mlir/IR/Types.h.
;; Imports raw C bindings from (mlir ir type ffi) and re-exports clean names.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir type)
  (export type-get-context)
  (import (rnrs) (mlir ir type ffi))

  ;; @brief mlir::Type::getContext() — return the MLIRContext that owns this type.
  ;; @param type  Type opaque pointer uptr
  ;; @return      MLIRContext opaque pointer uptr, or 0 if type is null
  ;; @see         mlir/IR/Types.h
  ;; @note        Defined in lib/Bindings/IR/Type.cpp
  (define type-get-context %type-get-context)

) ;; end library (mlir ir type)

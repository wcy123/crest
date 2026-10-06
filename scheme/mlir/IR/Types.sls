#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Types) — mlir::Type base class bindings.
;;
;; Mirrors mlir/IR/Types.h.
;; Imports raw C bindings from (mlir IR Types ffi) and re-exports clean names.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Types)
  (export mlir::Type::getContext)
  (import (rnrs) (mlir IR Types ffi))

  ;; @brief mlir::Type::getContext() — return the MLIRContext that owns this type.
  ;; @param type  Type opaque pointer uptr
  ;; @return      MLIRContext opaque pointer uptr, or 0 if type is null
  ;; @see         mlir/IR/Types.h
  ;; @note        Defined in lib/Bindings/IR/Type.cpp
  (define mlir::Type::getContext %mlir::Type::getContext)

  ) ;; end library (mlir IR Types)

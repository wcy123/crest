#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;
;; Mirrors mlir/IR/Types.h.
;;===----------------------------------------------------------------------===;;
;;
;; (mlir IR Types ffi) — raw C bindings for mlir/IR/Types.h.
;;
;; % prefix = raw C binding. Prefer (mlir IR Types) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir IR Types ffi)
  (export %mlir::Type::getContext)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::Type::getContext() — return the MLIRContext that owns this type.
  ;; @param type  Type opaque pointer uptr
  ;; @return      MLIRContext opaque pointer uptr, or 0 if type is null
  ;; @see         mlir/IR/Types.h
  ;; @note        Defined in lib/Bindings/IR/Type.cpp
  (define %mlir::Type::getContext
    (foreign-procedure "mlir::Type::getContext" (uptr) uptr))

) ;; end library (mlir IR Types ffi)

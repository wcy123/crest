#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir type ffi) — raw C bindings for mlir/IR/Types.h.
;;
;; % prefix = raw C binding. Prefer (mlir ir type) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir type ffi)
  (export %type-get-context)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::Type::getContext() — return the MLIRContext that owns this type.
  ;; @param type  Type opaque pointer uptr
  ;; @return      MLIRContext opaque pointer uptr, or 0 if type is null
  ;; @see         mlir/IR/Types.h
  ;; @note        Defined in lib/Bindings/IR/Type.cpp
  (define %type-get-context
    (foreign-procedure "mlir_ir_type_get_context" (uptr) uptr))

) ;; end library (mlir ir type ffi)

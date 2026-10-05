#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir op-result ffi) — raw C bindings for mlir::OpResult.
;;
;; % prefix = raw C binding. Prefer (mlir ir op-result) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir op-result ffi)
  (export %mlir::OpResult::getResultNumber)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::OpResult::getResultNumber — return the result index within the defining op.
  ;; @param value  Opaque Value* (mlir::OpResult) as uptr
  ;; @return       0-based result index as uptr; 0 if value is null or not an OpResult
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/OpResult.cpp; also registered as
  ;;               mlir_ir_value_get_result_number for backward compatibility
  (define %mlir::OpResult::getResultNumber
    (foreign-procedure "mlir::OpResult::getResultNumber" (uptr) uptr))

) ;; end library (mlir ir op-result ffi)

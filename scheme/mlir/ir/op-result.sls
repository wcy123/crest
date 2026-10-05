#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir op-result) — mlir::OpResult bindings.
;;
;; Mirrors mlir/IR/Value.h (OpResult is defined there alongside Value).
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir op-result)
  (export get-result-number)
  (import (rnrs) (mlir ir op-result ffi))

  ;; @brief mlir::OpResult::getResultNumber — return the result index within the defining op.
  ;; @param value  Opaque Value* (mlir::OpResult) as uptr
  ;; @return       0-based result index; 0 if value is null or not an OpResult
  ;; @see          mlir/IR/Value.h
  ;; @note         Defined in lib/Bindings/IR/OpResult.cpp
  (define get-result-number %get-result-number)

) ;; end library (mlir ir op-result)

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

  (define get-result-number %get-result-number)

) ;; end library (mlir ir op-result)

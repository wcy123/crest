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
  (export %get-result-number)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %get-result-number
    (foreign-procedure "mlir_ir_op_result_get_result_number" (uptr) uptr))

) ;; end library (mlir ir op-result ffi)

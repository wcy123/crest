#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir ir value ffi) — raw foreign-procedure bindings for mlir/IR/Value.h.
;;
;; All names have a % prefix to signal "raw C binding".
;; Import (mlir ir value) for the clean user-visible API.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir ir value ffi)
  (export
    %get-defining-op
    %block-argument?
    %get-result-number
    %num-uses
    %get-type)

  (import (rnrs)
          (only (chezscheme) foreign-procedure))

  (define %get-defining-op
    (foreign-procedure "mlir_ir_value_get_defining_op" (uptr) uptr))

  (define %block-argument?
    (foreign-procedure "mlir_ir_value_is_block_argument" (uptr) int))

  (define %get-result-number
    (foreign-procedure "mlir_ir_value_get_result_number" (uptr) int))

  (define %num-uses
    (foreign-procedure "mlir_ir_value_num_uses" (uptr) uptr))

  (define %get-type
    (foreign-procedure "mlir_ir_value_get_type" (uptr) uptr))

) ;; end library (mlir ir value ffi)

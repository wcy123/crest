#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir core value) — MLIR Value and ValueArrayRef primitives.
;;
;; Mirrors mlir/IR/Value.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir core value)
  (export
    mlir-value-get-defining-op
    mlir-value-get-type
    mlir-value-is-block-argument?
    mlir-value-get-result-number
    mlir-value-num-uses
    ;; Re-exported from (mlir support array-ref).
    array-ref-size
    array-ref-at
    make-array-ref
    array-ref-destroy
    with-array-ref
    :uptr               ; array-ref-at element type → 'uptr (8-byte pointer)
    :i32)               ; array-ref-at element type → 'i32  (4-byte integer)

  (import (rnrs)
          (only (chezscheme) foreign-procedure)
          (mlir support array-ref))

  ;; Return the operation that defines this value, or 0 for block arguments.
  ;; value: Value* opaque ptr uptr
  ;; Returns: Operation* uptr, or 0 if the value is a block argument
  (define mlir-value-get-defining-op
    (foreign-procedure "mlir_value_get_defining_op" (uptr) uptr))

  ;; Return the MLIR type of the value as an opaque Type pointer.
  ;; value: Value* opaque ptr uptr
  ;; Returns: Type opaque ptr uptr
  (define mlir-value-get-type
    (foreign-procedure "mlir_value_get_type" (uptr) uptr))

  ;; Raw predicate: returns 1 if the value is a block argument, 0 otherwise.
  ;; value: Value* opaque ptr uptr
  (define %mlir-value-is-block-argument
    (foreign-procedure "mlir_value_is_block_argument" (uptr) int))

  ;; Return #t if the value is a block argument (not an op result).
  ;; value: Value* opaque ptr uptr
  (define (mlir-value-is-block-argument? v)
    (= 1 (%mlir-value-is-block-argument v)))

  ;; Return the 0-based result number of this op-result value.
  ;; value: Value* opaque ptr uptr (must be an op result, not a block argument)
  ;; Returns: result index as int
  (define mlir-value-get-result-number
    (foreign-procedure "mlir_value_get_result_number" (uptr) int))

  ;; Return the number of uses of a Value.
  ;; Useful for single-use guards in pattern matching.
  ;; value: Value* opaque ptr uptr
  ;; Returns: use count as uptr (fixnum for typical counts)
  (define mlir-value-num-uses
    (foreign-procedure "mlir_value_num_uses" (uptr) uptr))

  ;; array-ref-size and array-ref-at are imported from
  ;; (mlir support array-ref) and re-exported above.

) ;; end library (mlir core value)

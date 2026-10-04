#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir core types) — backward-compatibility shim.
;;
;; The builtin dialect types have moved to (mlir dialects builtin).
;; This library re-exports everything so existing code continues to work.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir core types)
  (export
    mlir-type-get-context
    mlir-get-index-type
    mlir-get-i64-type
    mlir-get-i1-type
    mlir-type-is-ranked-tensor
    mlir-type-get-element-type
    mlir-type-get-shape
    mlir-type-get-rank
    mlir-type-element-type
    mlir-type-integer-width
    mlir-type-is-unsigned
    :uptr   ; array-ref-at element type → 'uptr (8-byte pointer / address)
    :i32)   ; array-ref-at element type → 'i32  (4-byte signed integer)
  (import (rnrs)
          (mlir dialects builtin))

  (define-syntax :uptr (identifier-syntax 'uptr))
  (define-syntax :i32  (identifier-syntax 'i32)))

;; end library (mlir core types)

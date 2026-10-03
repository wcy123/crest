#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir core types) — MLIR type constructors and queries.
;;
;; Mirrors mlir/IR/Builders.h (type factory methods) and mlir/IR/Types.h.
;; Type constructors accept an optional ctx argument; when omitted they
;; use (current-mlir-context) from (mlir core context).
;;
;;===----------------------------------------------------------------------===;;

(library (mlir core types)
  (export
    ;; Context extraction
    mlir-type-get-context
    ;; Type constructors (ctx optional — defaults to current-mlir-context)
    mlir-get-index-type
    mlir-get-i64-type
    mlir-get-i1-type
    ;; Type queries
    mlir-type-is-ranked-tensor
    mlir-type-get-element-type
    mlir-type-get-shape
    mlir-type-get-rank)
  (import (rnrs)
          (only (chezscheme) foreign-procedure)
          (mlir core context))

  ;; Get the MLIRContext* from any Type* (types carry their context).
  ;; type: Type opaque uptr
  ;; Returns: MLIRContext* uptr, or 0 on null input
  (define mlir-type-get-context
    (foreign-procedure "mlir_type_get_context" (uptr) uptr))

  ;; Private FFI bindings — always require an explicit ctx.
  ;; Callers should use the public wrappers below, which accept optional ctx.
  ;;   ctx: MLIRContext* uptr
  ;;   Returns: Type opaque uptr
  (define %mlir-get-index-type (foreign-procedure "mlir_get_index_type" (uptr) uptr))
  (define %mlir-get-i64-type   (foreign-procedure "mlir_get_i64_type"   (uptr) uptr))
  (define %mlir-get-i1-type    (foreign-procedure "mlir_get_i1_type"    (uptr) uptr))

  ;; Return (current-mlir-context), raising with a clear message if unset.
  ;; who: symbol — used as the error source
  ;; Returns: MLIRContext* uptr
  (define (%require-context who)
    (or (current-mlir-context)
        (error who "no current MLIRContext — wrap with (with-mlir-context ctx ...)")))

  ;; Internal macro: generate a public wrapper that makes the ctx argument
  ;; optional, falling back to (current-mlir-context).
  (define-syntax define-ctx-optional
    (syntax-rules ()
      [(_ name impl)
       (define name
         (case-lambda
           [()    (impl (%require-context 'name))]
           [(ctx) (impl ctx)]))]))

  ;; Type constructors — ctx: MLIRContext* uptr (optional)
  ;; mlir-get-index-type → IndexType opaque uptr
  ;; mlir-get-i64-type   → IntegerType<64> opaque uptr
  ;; mlir-get-i1-type    → IntegerType<1> opaque uptr
  (define-ctx-optional mlir-get-index-type %mlir-get-index-type)
  (define-ctx-optional mlir-get-i64-type   %mlir-get-i64-type)
  (define-ctx-optional mlir-get-i1-type    %mlir-get-i1-type)

  ;; Returns 1 if the type is a RankedTensorType, 0 otherwise.
  ;; type: Type opaque uptr  Returns: int (1 = true, 0 = false)
  (define mlir-type-is-ranked-tensor
    (foreign-procedure "mlir_type_is_ranked_tensor" (uptr) int))

  ;; Get the element type of a shaped type (tensor, memref, vector).
  ;; type: ShapedType opaque uptr  Returns: element Type opaque uptr
  (define mlir-type-get-element-type
    (foreign-procedure "mlir_type_get_element_type" (uptr) uptr))

  ;; Get the shape of a ranked tensor as a Scheme list of exact integers.
  ;; Negative values indicate dynamic dimensions (mlir::ShapedType::kDynamic).
  ;; type: RankedTensorType opaque uptr  Returns: list of exact integers
  (define mlir-type-get-shape
    (foreign-procedure "mlir_type_get_shape" (uptr) scheme-object))

  ;; Get the rank (number of dimensions) of a ranked tensor type.
  ;; type: RankedTensorType opaque uptr  Returns: non-negative int
  (define mlir-type-get-rank
    (foreign-procedure "mlir_type_get_rank" (uptr) int))

) ;; end library (mlir core types)

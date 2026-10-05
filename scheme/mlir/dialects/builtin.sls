#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir dialects builtin) — MLIR builtin dialect: type constructors and queries.
;;
;; The builtin dialect is MLIR's fundamental built-in dialect.  Its types
;; (IntegerType, FloatType, IndexType, RankedTensorType, etc.) are defined in
;; mlir/IR/BuiltinTypes.h and registered as part of mlir::BuiltinDialect.
;;
;; Type constructors accept an optional ctx argument; when omitted they
;; use (current-mlir-context) from (mlir core context).
;;
;;===----------------------------------------------------------------------===;;

(library (mlir dialects builtin)
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
    mlir-type-get-rank
    mlir-ranked-tensor-type-get-encoding  ; encoding Attribute of a RankedTensorType (0 if absent)
    ;; Integer type queries
    mlir-type-element-type    ; element type of ShapedType (uptr → uptr)
    mlir-type-integer-width   ; bit width of IntegerType (uptr → uptr)
    mlir-type-is-unsigned)    ; #t if unsigned IntegerType (uptr → boolean)
  (import (rnrs)
          (mlir core context)
          (mlir dialects builtin ffi))

  ;; Get the MLIRContext* from any Type* (types carry their context).
  (define mlir-type-get-context %type-get-context)

  ;; Private FFI bindings — always require an explicit ctx.
  (define %mlir-get-index-type %get-index-type)
  (define %mlir-get-i64-type   %get-i64-type)
  (define %mlir-get-i1-type    %get-i1-type)

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

  (define mlir-type-is-ranked-tensor       %type-is-ranked-tensor)
  (define mlir-type-get-element-type       %type-get-element-type)
  (define mlir-type-get-shape              %type-get-shape)
  (define mlir-type-get-rank               %type-get-rank)
  (define mlir-ranked-tensor-type-get-encoding %ranked-tensor-type-get-encoding)
  (define mlir-type-element-type           %type-element-type)
  (define mlir-type-integer-width          %type-integer-width)
  (define mlir-type-is-unsigned
    (lambda (t) (not (zero? (%type-is-unsigned t)))))

) ;; end library (mlir core types)

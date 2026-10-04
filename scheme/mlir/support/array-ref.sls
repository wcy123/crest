#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support array-ref) — C ABI helpers for ArrayRef<T> structs.
;;
;; Struct layout (matching llvm::ArrayRef<T> ABI, 64-bit):
;;   offset 0: data uptr   — pointer to first element
;;   offset 8: size uptr   — number of elements
;;
;; Performance design:
;;   array-ref-size, array-ref-at — foreign-ref (zero FFI overhead, raw loads)
;;   make-array-ref, array-ref-destroy — C++ FFI (acceptable for lifecycle)
;;   with-array-ref — macro: RAII wrapper via dynamic-wind
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support array-ref)
  (export
    array-ref-size      ; (ref) → element count, zero FFI overhead
    array-ref-at        ; (ref index [type]) → element, bounds-checked
    make-array-ref      ; (data-ptr size) → ref  [C heap allocation]
    array-ref-destroy   ; (ref) → void           [C heap free]
    with-array-ref      ; (syntax) RAII: make + body + destroy
    :uptr)              ; array-ref-at element type → 'uptr (8-byte pointer, default)
                        ; :i32 comes from (mlir core attribute) — not re-exported here

  (import (rnrs)
          (only (chezscheme) foreign-procedure foreign-ref)
          (only (mlir core types) :uptr :i32))

  ;;===--------------------------------------------------------------------===;;
  ;; Fast path — foreign-ref compiles to raw load instructions, no FFI call.
  ;;===--------------------------------------------------------------------===;;

  ;; Return the number of elements — reads size field at offset 8.
  (define (array-ref-size ref)
    (foreign-ref 'uptr ref 8))

  ;; Return the i-th element with bounds check.
  ;; type: element type symbol — 'uptr (default, 8-byte pointer) or 'i32 (4-byte integer).
  ;;   'uptr → foreign-ref 'uptr        at offset index*8  (Value*, Operation*, etc.)
  ;;   'i32  → foreign-ref 'integer-32  at offset index*4  (DenseI32ArrayAttr data)
  ;; Use :uptr (exported here) or :i32 (from (mlir core attribute)) as compile-time keywords.
  (define array-ref-at
    (case-lambda
      [(ref index)
       (array-ref-at ref index 'uptr)]
      [(ref index type)
       (let ([size (foreign-ref 'uptr ref 8)]
             [data (foreign-ref 'uptr ref 0)])
         (when (>= index size)
           (error 'array-ref-at "index out of range" index size))
         (cond
           [(eq? type :uptr) (foreign-ref 'uptr       data (* index 8))]
           [(eq? type :i32)  (foreign-ref 'integer-32 data (* index 4))]
           [else             (error 'array-ref-at "unknown type (expected :uptr or :i32)" type)]))]))

  ;;===--------------------------------------------------------------------===;;
  ;; Lifecycle — C++ FFI (one call per array lifetime, overhead acceptable).
  ;;===--------------------------------------------------------------------===;;

  ;; Allocate a CArrayRef on the C heap. Returns a uptr (raw C address).
  ;; Must be paired with array-ref-destroy, or use with-array-ref.
  (define make-array-ref
    (foreign-procedure "mlir_array_ref_make" (uptr uptr) uptr))

  ;; Free a CArrayRef previously created by make-array-ref.
  (define array-ref-destroy
    (foreign-procedure "mlir_array_ref_destroy" (uptr) void))

  ;;===--------------------------------------------------------------------===;;
  ;; with-array-ref — RAII macro.
  ;; Guarantees array-ref-destroy is called even on exception (dynamic-wind).
  ;;===--------------------------------------------------------------------===;;

  (define-syntax with-array-ref
    (syntax-rules ()
      ;; (with-array-ref (name existing-ref) body ...)
      ;; Manage an existing array-ref uptr — destroyed on exit even on exception.
      [(_ (name ref-expr) body ...)
       (let ([name ref-expr])
         (dynamic-wind
           (lambda () #f)
           (lambda () body ...)
           (lambda () (array-ref-destroy name))))]
      ;; (with-array-ref (name data-ptr size) body ...)
      ;; Allocate a new CArrayRef from data pointer + element count.
      [(_ (name data-ptr size) body ...)
       (let ([name (make-array-ref data-ptr size)])
         (dynamic-wind
           (lambda () #f)
           (lambda () body ...)
           (lambda () (array-ref-destroy name))))]))

) ;; end library (mlir support array-ref)

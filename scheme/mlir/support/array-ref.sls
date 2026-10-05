#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;  (CREST-specific — no direct MLIR header mirror.)
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support array-ref) — C ABI helpers for ArrayRef<T> structs.
;;
;; CREST-specific (no direct MLIR header); mirrors lib/Bindings/Support/ArrayRef.h.
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
                        ; :i32 is a local keyword synonym — 'i32

  (import (rnrs)
          (only (chezscheme) foreign-ref)
          (mlir support array-ref ffi))

  ;; @brief Compile-time keyword: element type 'uptr — 8-byte pointer (Value*, Operation*, etc.).
  ;; @note  Pass as the optional third argument to array-ref-at
  ;; @note  :i32 is internal — the symbol 'i32 used as the element type tag
  (define-syntax :uptr (identifier-syntax 'uptr))
  (define-syntax :i32  (identifier-syntax 'i32))

  ;;===--------------------------------------------------------------------===;;
  ;; Fast path — foreign-ref compiles to raw load instructions, no FFI call.
  ;;===--------------------------------------------------------------------===;;

  ;; @brief Read element count from a CArrayRef struct.
  ;; @param ref    uptr — pointer to CArrayRef{uint64_t data; uint64_t size}
  ;; @return       Number of elements (uptr, reads size field at offset 8)
  ;; @note         Zero FFI overhead — compiles to a raw memory load via foreign-ref
  ;; @note         Struct layout defined in lib/Bindings/Support/ArrayRef.h
  (define (array-ref-size ref)
    (foreign-ref 'uptr ref 8))

  ;; @brief Read the i-th element from a CArrayRef with bounds checking.
  ;; @param ref    uptr — pointer to CArrayRef{data; size}
  ;; @param index  Exact non-negative integer — zero-based element index
  ;; @param type   (optional) Element type symbol; default is 'uptr
  ;;               :uptr → foreign-ref 'uptr       at offset index*8  (Value*, Operation*, etc.)
  ;;               :i32  → foreign-ref 'integer-32  at offset index*4  (DenseI32ArrayAttr data)
  ;; @return       Element value as uptr or integer-32 depending on type
  ;; @note         Raises error 'array-ref-at if index >= size
  ;; @note         Zero FFI overhead — compiles to raw memory loads via foreign-ref
  ;; @note         Use :uptr or :i32 compile-time keywords as the type argument
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

  ;; @brief Allocate a CArrayRef on the C heap.
  ;; @param data-ptr  uptr — pointer to the first element of the backing array
  ;; @param size      uptr — number of elements
  ;; @return          uptr — address of the newly allocated CArrayRef
  ;; @note            Must be paired with array-ref-destroy, or use with-array-ref (RAII)
  ;; @note            Defined in lib/Bindings/Support/ArrayRef.cpp
  (define make-array-ref %make)

  ;; @brief Free a CArrayRef previously created by make-array-ref.
  ;; @param ref  uptr — address returned by make-array-ref
  ;; @return     void
  ;; @note       Do not call twice on the same pointer (double-free is UB)
  ;; @note       Defined in lib/Bindings/Support/ArrayRef.cpp
  (define array-ref-destroy %destroy)

  ;;===--------------------------------------------------------------------===;;
  ;; with-array-ref — RAII macro.
  ;; Guarantees array-ref-destroy is called even on exception (dynamic-wind).
  ;;===--------------------------------------------------------------------===;;

  ;; @brief RAII macro — create or adopt a CArrayRef and guarantee its destruction.
  ;;
  ;; Two forms:
  ;;
  ;;   (with-array-ref (name existing-ref) body ...)
  ;;     Adopt an existing CArrayRef uptr.  name is bound to existing-ref inside body.
  ;;     array-ref-destroy is called on name when body exits (normally or via exception).
  ;;
  ;;   (with-array-ref (name data-ptr size) body ...)
  ;;     Allocate a new CArrayRef via make-array-ref.  name is bound to the new uptr.
  ;;     array-ref-destroy is called on name when body exits (normally or via exception).
  ;;
  ;; @param name      Identifier to bind the CArrayRef uptr inside body
  ;; @param ref-expr  (1-arg form) uptr — address of an existing CArrayRef
  ;; @param data-ptr  (2-arg form) uptr — pointer to backing array data
  ;; @param size      (2-arg form) uptr — element count
  ;; @param body      One or more expressions evaluated with name in scope
  ;; @return          Value of the last body expression
  ;; @note            Implemented via dynamic-wind; destruction runs even on exceptions
  ;; @note            Do not let name escape body — it is freed on exit
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

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;; Mirrors lib/Bindings/Support/ArrayRef.h (CREST-specific, no MLIR counterpart).
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support array-ref) — C ABI helpers for CArrayRef.
;;
;; CArrayRef<T> layout (64-bit), from lib/Bindings/Support/ArrayRef.h:
;;   offset 0:  deletor (8B) — function pointer (type tag + destructor)
;;   offset 8:  data    (8B) — non-owning const T* pointer to first element
;;   offset 16: size    (8B) — number of elements
;;
;; Three typed instantiations:
;;   CArrayRef<i32>  — int32_t elements (stride 4B); crest::CArrayRef<i32>?
;;   CArrayRef<i64>  — int64_t elements (stride 8B); crest::CArrayRef<i64>?
;;   CArrayRef<uptr> — uintptr_t elements (stride 8B); crest::CArrayRef<uptr>?
;;
;; Each has a unique deletor address (type tag). crest::CArrayRef::at dispatches on
;; the runtime type — no explicit element-type keyword needed.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support array-ref)
  (export
    ;; Typed CArrayRef predicates
    crest::CArrayRef<i32>?         ; (obj) → boolean
    crest::CArrayRef<i64>?         ; (obj) → boolean
    crest::CArrayRef<uptr>?        ; (obj) → boolean
    crest::CArrayRef?              ; (obj) → boolean: any CArrayRef<T>
    ;; CArrayRef accessors
    crest::CArrayRef::size          ; (ref) → fixnum: element count
    crest::CArrayRef::at            ; (ref index) → element value (type inferred)
    crest::CArrayRef<uptr>::CArrayRef          ; (data-ptr size) → CArrayRef<uptr> [heap alloc]
    with-ArrayRef)          ; (syntax) RAII for CArrayRef

  (import (rnrs)
          (only (chezscheme) foreign-ref)
          (only (mlir support CrestObject) with-CrestObject)
          (mlir support array-ref ffi))

  ;;===--------------------------------------------------------------------===;;
  ;; Typed CArrayRef predicates.
  ;; The isa logic (deletor comparison) is in C++ via %crest::CArrayRef<T>?.
  ;;===--------------------------------------------------------------------===;;

  ;; @brief crest::CArrayRef<i32>? — is this a CArrayRef<int32_t>?
  (define (crest::CArrayRef<i32>?  obj) (not (zero? (%crest::CArrayRef<i32>?  obj))))
  ;; @brief crest::CArrayRef<i64>? — is this a CArrayRef<int64_t>?
  (define (crest::CArrayRef<i64>?  obj) (not (zero? (%crest::CArrayRef<i64>?  obj))))
  ;; @brief crest::CArrayRef<uptr>? — is this a CArrayRef<uintptr_t>?
  (define (crest::CArrayRef<uptr>? obj) (not (zero? (%crest::CArrayRef<uptr>? obj))))
  ;; @brief crest::CArrayRef? — is this any typed CArrayRef<T>?
  (define (crest::CArrayRef? obj)
    (or (crest::CArrayRef<i32>? obj) (crest::CArrayRef<i64>? obj) (crest::CArrayRef<uptr>? obj)))

  ;;===--------------------------------------------------------------------===;;
  ;; CArrayRef accessors.
  ;; Layout: { deletor@0(8B), data@8(8B), size@16(8B) }
  ;;===--------------------------------------------------------------------===;;

  ;; @brief crest::CArrayRef::size — read element count from a CArrayRef.
  ;; @param ref  uptr — pointer to any CArrayRef<T>
  ;; @return     fixnum element count
  (define (crest::CArrayRef::size ref)
    (foreign-ref 'uptr ref 16))

  ;; @brief crest::CArrayRef::at — read the i-th element, dispatching on the runtime type.
  ;; @param ref    uptr — pointer to a typed CArrayRef<T>
  ;; @param index  0-based exact integer
  ;; @return       element value (integer-32 for i32, integer-64 for i64, uptr for uptr)
  ;; @error        raises 'crest::CArrayRef::at if index out of range or unknown type
  (define (crest::CArrayRef::at ref index)
    (let ([n    (foreign-ref 'uptr ref 16)]
          [data (foreign-ref 'uptr ref 8)])
      (unless (and (>= index 0) (< index n))
        (error 'crest::CArrayRef::at "index out of range" index n))
      (cond
       [(crest::CArrayRef<i32>?  ref) (foreign-ref 'integer-32 data (* index 4))]
       [(crest::CArrayRef<i64>?  ref) (foreign-ref 'integer-64 data (* index 8))]
       [(crest::CArrayRef<uptr>? ref) (foreign-ref 'uptr       data (* index 8))]
       [else (error 'crest::CArrayRef::at "unknown CArrayRef element type")])))

  ;; @brief crest::CArrayRef<uptr>::CArrayRef — allocate a CArrayRef<uintptr_t> on the C heap.
  ;; @param data-ptr  uptr — pointer to backing array data
  ;; @param size      uptr — element count
  ;; @return          uptr — new CArrayRef<uptr>; use with-ArrayRef for cleanup
  (define crest::CArrayRef<uptr>::CArrayRef %crest::CArrayRef<uptr>::CArrayRef)

  ;; @brief with-ArrayRef — RAII for CArrayRef; calls crest::CrestObject::delete on exit.
  ;;
  ;; Two forms:
  ;;   (with-ArrayRef name (existing-ref) body ...)  — adopt existing CArrayRef
  ;;   (with-ArrayRef name (data-ptr size) body ...)  — allocate + adopt
  (define-syntax with-ArrayRef
    (syntax-rules ()
      [(_ name (ref-expr) body ...)
       (with-CrestObject name ref-expr body ...)]
      [(_ name (data-ptr size) body ...)
       (with-CrestObject name (crest::CArrayRef<uptr>::CArrayRef data-ptr size) body ...)]))

  ) ;; end library (mlir support array-ref)

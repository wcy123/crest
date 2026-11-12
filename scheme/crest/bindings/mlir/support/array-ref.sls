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
;; CArrayRef<uptr> — uintptr_t elements (stride 8B); crest::CArrayRef<uptr>? A C++ pattern gives
;; one to Scheme as `operands-ref`; it is a view that C++ owns, so Scheme never makes or frees one.
;; (The old heap-allocated CArrayRefs of DenseI32/I64 arrays, and with-ArrayRef, were removed: a view
;; that Scheme had to free leaked when it forgot to. DenseI32ArrayAttr::asArrayRef answers a list.)
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support array-ref)
  (export
    ;; CArrayRef predicate
    crest::CArrayRef<uptr>?        ; (obj) → boolean
    crest::CArrayRef?              ; (obj) → boolean: any CArrayRef<T>
    ;; CArrayRef accessors
    crest::CArrayRef::size          ; (ref) → fixnum: element count
    crest::CArrayRef::at)           ; (ref index) → element value

  (import (rnrs)
          (only (chezscheme) foreign-ref)
          (mlir support array-ref ffi))

  ;;===--------------------------------------------------------------------===;;
  ;; Typed CArrayRef predicates.
  ;; The isa logic (deletor comparison) is in C++ via %crest::CArrayRef<T>?.
  ;;===--------------------------------------------------------------------===;;

  ;; @brief crest::CArrayRef<uptr>? — is this a CArrayRef<uintptr_t>?
  (define (crest::CArrayRef<uptr>? obj) (not (zero? (%crest::CArrayRef<uptr>? obj))))
  ;; @brief crest::CArrayRef? — is this any typed CArrayRef<T>?
  (define (crest::CArrayRef? obj)
    (crest::CArrayRef<uptr>? obj))

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
  ;; @return       element value (uptr)
  ;; @error        raises 'crest::CArrayRef::at if index out of range or unknown type
  (define (crest::CArrayRef::at ref index)
    (let ([n    (foreign-ref 'uptr ref 16)]
          [data (foreign-ref 'uptr ref 8)])
      (unless (and (>= index 0) (< index n))
        (error 'crest::CArrayRef::at "index out of range" index n))
      (cond
       [(crest::CArrayRef<uptr>? ref) (foreign-ref 'uptr       data (* index 8))]
       [else (error 'crest::CArrayRef::at "unknown CArrayRef element type")])))

  ) ;; end library (mlir support array-ref)

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;; Mirrors lib/Bindings/Support/ArrayRef.h (CREST-specific, no MLIR counterpart).
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support array-ref) — C ABI helpers for CArrayRef and CrestObject.
;;
;; CArrayRef<T> layout (64-bit), from lib/Bindings/Support/ArrayRef.h:
;;   offset 0:  deletor (8B) — function pointer (type tag + destructor)
;;   offset 8:  data    (8B) — non-owning const T* pointer to first element
;;   offset 16: size    (8B) — number of elements
;;
;; Three typed instantiations:
;;   CArrayRef<i32>  — int32_t elements (stride 4B); CArrayRef<i32>?
;;   CArrayRef<i64>  — int64_t elements (stride 8B); CArrayRef<i64>?
;;   CArrayRef<uptr> — uintptr_t elements (stride 8B); CArrayRef<uptr>?
;;
;; Each has a unique deletor address (type tag). ArrayRef::at dispatches on
;; the runtime type — no explicit element-type keyword needed.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support array-ref)
  (export
    ;; CrestObject — generic base for all CREST-managed foreign objects
    CrestObject::deletor    ; (obj) → uptr: read deletor address (type tag)
    CrestObject::delete     ; (obj) → void: call deletor, freeing the object
    with-CrestObject        ; (syntax) RAII for any CrestObject
    ;; Typed CArrayRef predicates
    CArrayRef<i32>?         ; (obj) → boolean
    CArrayRef<i64>?         ; (obj) → boolean
    CArrayRef<uptr>?        ; (obj) → boolean
    CArrayRef?              ; (obj) → boolean: any CArrayRef<T>
    ;; CArrayRef accessors
    ArrayRef::size          ; (ref) → fixnum: element count
    ArrayRef::at            ; (ref index) → element value (type inferred)
    make-array-ref          ; (data-ptr size) → CArrayRef<uptr> [heap alloc]
    with-ArrayRef)          ; (syntax) RAII for CArrayRef

  (import (rnrs)
          (only (chezscheme) foreign-ref)
          (mlir support array-ref ffi))

  ;;===--------------------------------------------------------------------===;;
  ;; CrestObject — generic base for heap-allocated CREST foreign objects.
  ;;===--------------------------------------------------------------------===;;

  ;; @brief CrestObject::deletor — read the deletor (type tag) from a CrestObject.
  ;; @param obj  uptr — pointer to any CrestObject
  ;; @return     uptr — address of the deletor function (unique per concrete type)
  (define (CrestObject::deletor obj)
    (foreign-ref 'uptr obj 0))

  ;; @brief CrestObject::delete — call the stored deletor, freeing the object.
  ;; @param obj  uptr — pointer to any CrestObject
  (define CrestObject::delete %CrestObject::delete)

  ;; @brief with-CrestObject — RAII for any CrestObject.
  (define-syntax with-CrestObject
    (syntax-rules ()
      [(_ (name expr) body ...)
       (let ([name expr])
         (dynamic-wind
             (lambda () #f)
             (lambda () body ...)
             (lambda () (CrestObject::delete name))))]))

  ;;===--------------------------------------------------------------------===;;
  ;; Typed CArrayRef predicates.
  ;; The isa logic (deletor comparison) is in C++ via %CArrayRef<T>::isa.
  ;;===--------------------------------------------------------------------===;;

  ;; @brief CArrayRef<i32>? — is this a CArrayRef<int32_t>?
  (define (CArrayRef<i32>?  obj) (not (zero? (%CArrayRef<i32>::isa  obj))))
  ;; @brief CArrayRef<i64>? — is this a CArrayRef<int64_t>?
  (define (CArrayRef<i64>?  obj) (not (zero? (%CArrayRef<i64>::isa  obj))))
  ;; @brief CArrayRef<uptr>? — is this a CArrayRef<uintptr_t>?
  (define (CArrayRef<uptr>? obj) (not (zero? (%CArrayRef<uptr>::isa obj))))
  ;; @brief CArrayRef? — is this any typed CArrayRef<T>?
  (define (CArrayRef? obj)
    (or (CArrayRef<i32>? obj) (CArrayRef<i64>? obj) (CArrayRef<uptr>? obj)))

  ;;===--------------------------------------------------------------------===;;
  ;; CArrayRef accessors.
  ;; Layout: { deletor@0(8B), data@8(8B), size@16(8B) }
  ;;===--------------------------------------------------------------------===;;

  ;; @brief ArrayRef::size — read element count from a CArrayRef.
  ;; @param ref  uptr — pointer to any CArrayRef<T>
  ;; @return     fixnum element count
  (define (ArrayRef::size ref)
    (foreign-ref 'uptr ref 16))

  ;; @brief ArrayRef::at — read the i-th element, dispatching on the runtime type.
  ;; @param ref    uptr — pointer to a typed CArrayRef<T>
  ;; @param index  0-based exact integer
  ;; @return       element value (integer-32 for i32, integer-64 for i64, uptr for uptr)
  ;; @error        raises 'ArrayRef::at if index out of range or unknown type
  (define (ArrayRef::at ref index)
    (let ([n    (foreign-ref 'uptr ref 16)]
          [data (foreign-ref 'uptr ref 8)])
      (unless (and (>= index 0) (< index n))
        (error 'ArrayRef::at "index out of range" index n))
      (cond
       [(CArrayRef<i32>?  ref) (foreign-ref 'integer-32 data (* index 4))]
       [(CArrayRef<i64>?  ref) (foreign-ref 'integer-64 data (* index 8))]
       [(CArrayRef<uptr>? ref) (foreign-ref 'uptr       data (* index 8))]
       [else (error 'ArrayRef::at "unknown CArrayRef element type")])))

  ;; @brief make-array-ref — allocate a CArrayRef<uintptr_t> on the C heap.
  ;; @param data-ptr  uptr — pointer to backing array data
  ;; @param size      uptr — element count
  ;; @return          uptr — new CArrayRef<uptr>; use with-ArrayRef for cleanup
  (define make-array-ref %make)

  ;; @brief with-ArrayRef — RAII for CArrayRef; calls CrestObject::delete on exit.
  ;;
  ;; Two forms:
  ;;   (with-ArrayRef (name existing-ref) body ...)  — adopt existing CArrayRef
  ;;   (with-ArrayRef (name data-ptr size) body ...)  — allocate + adopt
  (define-syntax with-ArrayRef
    (syntax-rules ()
      [(_ (name ref-expr) body ...)
       (with-CrestObject (name ref-expr) body ...)]
      [(_ (name data-ptr size) body ...)
       (with-CrestObject (name (make-array-ref data-ptr size)) body ...)]))

  ) ;; end library (mlir support array-ref)

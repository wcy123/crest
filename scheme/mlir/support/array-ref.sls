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
;; CArrayRef layout (64-bit), from lib/Bindings/Support/ArrayRef.h:
;;   offset 0:  deletor (8B) — function pointer (type tag + destructor)
;;   offset 8:  data    (8B) — non-owning pointer to first element
;;   offset 16: size    (8B) — number of elements
;;
;; CrestObject layout:
;;   offset 0:  deletor (8B) — same field; every CrestObject starts with deletor
;;
;; Performance design:
;;   CrestObject::deletor, ArrayRef::size, ArrayRef::at — foreign-ref (zero overhead)
;;   CrestObject::delete — C++ FFI (needs trampoline to call function pointer)
;;   with-ArrayRef, with-CrestObject — RAII macros via dynamic-wind
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support array-ref)
  (export
    ;; CrestObject — generic base for all CREST-managed foreign objects
    CrestObject::deletor    ; (obj) → uptr: read deletor address (type tag)
    CrestObject::delete     ; (obj) → void: call deletor, freeing the object
    with-CrestObject        ; (syntax) RAII for any CrestObject
    ;; CArrayRef — specific CrestObject for (data, size) pairs
    CArrayRef?              ; (obj) → boolean: is obj a CArrayRef?
    ArrayRef::size          ; (ref) → fixnum: element count
    ArrayRef::at            ; (ref index type) → element value
    make-array-ref          ; (data-ptr size) → ref [heap alloc, use with-ArrayRef]
    with-ArrayRef           ; (syntax) RAII for CArrayRef
    :uptr                   ; element type keyword — 8-byte pointer
    :i32                    ; element type keyword — 4-byte signed integer
    :i64)                   ; element type keyword — 8-byte signed integer

  (import (rnrs)
          (only (chezscheme) foreign-ref)
          (mlir support array-ref ffi))

  (define-syntax :uptr (identifier-syntax 'uptr))
  (define-syntax :i32  (identifier-syntax 'i32))
  (define-syntax :i64  (identifier-syntax 'i64))

  ;;===--------------------------------------------------------------------===;;
  ;; CrestObject — generic base for heap-allocated CREST foreign objects.
  ;; All CrestObjects start with a deletor function pointer at offset 0.
  ;;===--------------------------------------------------------------------===;;

  ;; @brief CrestObject::deletor — read the deletor (type tag) from a CrestObject.
  ;; @param obj  uptr — pointer to any CrestObject
  ;; @return     uptr — address of the deletor function (unique per concrete type)
  ;; @note       Zero FFI overhead — single foreign-ref load at offset 0
  (define (CrestObject::deletor obj)
    (foreign-ref 'uptr obj 0))

  ;; @brief CrestObject::delete — call the stored deletor, freeing the object.
  ;; @param obj  uptr — pointer to any CrestObject
  ;; @note       Cannot be done from pure Scheme — requires C trampoline to
  ;;             dereference and invoke an arbitrary function pointer
  (define CrestObject::delete %CrestObject::delete)

  ;; @brief with-CrestObject — RAII for any CrestObject.
  ;; Guarantees CrestObject::delete is called even on exception.
  (define-syntax with-CrestObject
    (syntax-rules ()
      [(_ (name expr) body ...)
       (let ([name expr])
         (dynamic-wind
             (lambda () #f)
             (lambda () body ...)
             (lambda () (CrestObject::delete name))))]))

  ;;===--------------------------------------------------------------------===;;
  ;; CArrayRef — a CrestObject with (data, size).
  ;; Layout: { deletor@0, data@8, size@16 }
  ;;===--------------------------------------------------------------------===;;

  ;; Type tag: obtained once at library load time by constructing a dummy
  ;; CArrayRef, reading its deletor, then freeing it.
  (define %carray-ref-type-tag
    (let ([dummy (%make 0 0)])
      (let ([tag (foreign-ref 'uptr dummy 0)])
        (CrestObject::delete dummy)
        tag)))

  ;; @brief CArrayRef? — is this CrestObject a CArrayRef?
  ;; @param obj  uptr — pointer to any CrestObject
  ;; @return     boolean: #t if obj was allocated as a CArrayRef
  (define (CArrayRef? obj)
    (= (CrestObject::deletor obj) %carray-ref-type-tag))

  ;; @brief ArrayRef::size — read element count from a CArrayRef.
  ;; @param ref  uptr — pointer to CArrayRef
  ;; @return     fixnum element count (reads size field at offset 16)
  ;; @note       Zero FFI overhead — raw memory load via foreign-ref
  (define (ArrayRef::size ref)
    (foreign-ref 'uptr ref 16))

  ;; @brief ArrayRef::at — read the i-th element from a CArrayRef.
  ;; @param ref    uptr — pointer to CArrayRef
  ;; @param index  exact non-negative integer (0-based)
  ;; @param type   element type keyword: :uptr (8B ptr), :i32 (4B int), :i64 (8B int)
  ;; @return       element value
  ;; @error        raises 'ArrayRef::at if index >= size
  ;; @note         Zero FFI overhead — raw memory loads via foreign-ref
  (define ArrayRef::at
    (case-lambda
     [(ref index)
      (ArrayRef::at ref index 'uptr)]
     [(ref index type)
      (let ([size (foreign-ref 'uptr ref 16)]
            [data (foreign-ref 'uptr ref 8)])
        (when (>= index size)
          (error 'ArrayRef::at "index out of range" index size))
        (cond
         [(eq? type :uptr) (foreign-ref 'uptr       data (* index 8))]
         [(eq? type :i32)  (foreign-ref 'integer-32 data (* index 4))]
         [(eq? type :i64)  (foreign-ref 'integer-64 data (* index 8))]
         [else             (error 'ArrayRef::at
                                  "unknown type (expected :uptr, :i32, or :i64)"
                                  type)]))]))

  ;; @brief make-array-ref — allocate a CArrayRef on the C heap.
  ;; @param data-ptr  uptr — pointer to backing array data
  ;; @param size      uptr — element count
  ;; @return          uptr — address of new CArrayRef; use with-ArrayRef for cleanup
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

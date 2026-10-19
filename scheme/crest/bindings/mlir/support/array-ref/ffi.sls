#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;; Mirrors lib/Bindings/Support/ArrayRef.h (CREST-specific, no MLIR counterpart).
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support array-ref ffi) — raw C bindings for CArrayRef lifecycle.
;;
;; % prefix = raw C binding. Prefer (mlir support array-ref) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support array-ref ffi)
  (export %make %CrestObject::delete
          %CArrayRef<i32>::isa
          %CArrayRef<i64>::isa
          %CArrayRef<uptr>::isa)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief Allocate a CArrayRef<uintptr_t> on the C heap.
  ;; @param data-ptr  uptr — pointer to the first element
  ;; @param size      uptr — number of elements
  ;; @return          uptr — address of newly allocated CArrayRef<uintptr_t>
  ;;                  Layout: { deletor@0, data@8, size@16 }
  (define %make
    (foreign-procedure "mlir_support_array_ref_make" (uptr uptr) uptr))

  ;; @brief Call the deletor stored in a CrestObject, freeing it.
  (define %CrestObject::delete
    (foreign-procedure "CrestObject::delete" (uptr) void))

  ;; @brief Type predicates — is this CrestObject a CArrayRef<T>?
  ;; Returns 1 (true) or 0 (false). The isa logic (deletor comparison) is in C++.
  (define %CArrayRef<i32>::isa
    (foreign-procedure "CArrayRef<i32>::isa" (uptr) int))
  (define %CArrayRef<i64>::isa
    (foreign-procedure "CArrayRef<i64>::isa" (uptr) int))
  (define %CArrayRef<uptr>::isa
    (foreign-procedure "CArrayRef<uptr>::isa" (uptr) int))

  ) ;; end library (mlir support array-ref ffi)

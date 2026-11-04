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
  (export %make
          %crest::CArrayRef<i32>?
          %crest::CArrayRef<i64>?
          %crest::CArrayRef<uptr>?)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief Allocate a CArrayRef<uintptr_t> on the C heap.
  ;; @param data-ptr  uptr — pointer to the first element
  ;; @param size      uptr — number of elements
  ;; @return          uptr — address of newly allocated CArrayRef<uintptr_t>
  ;;                  Layout: { deletor@0, data@8, size@16 }
  (define %make
    (foreign-procedure "mlir_support_array_ref_make" (uptr uptr) uptr))

  ;; @brief Type predicates — is this CrestObject a CArrayRef<T>?
  ;; Returns 1 (true) or 0 (false). The isa logic (deletor comparison) is in C++.
  (define %crest::CArrayRef<i32>?
    (foreign-procedure "crest::CArrayRef<i32>?" (uptr) int))
  (define %crest::CArrayRef<i64>?
    (foreign-procedure "crest::CArrayRef<i64>?" (uptr) int))
  (define %crest::CArrayRef<uptr>?
    (foreign-procedure "crest::CArrayRef<uptr>?" (uptr) int))

  ) ;; end library (mlir support array-ref ffi)

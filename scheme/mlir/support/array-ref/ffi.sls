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
;; CREST-specific (no direct MLIR header); mirrors lib/Bindings/Support/ArrayRef.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support array-ref ffi)
  (export %make %destroy)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief Allocate a CArrayRef struct on the C heap.
  ;; @param data-ptr  uptr — pointer to the first element of the array
  ;; @param size      uptr — number of elements in the array
  ;; @return          uptr — address of a newly allocated CArrayRef{data, size}
  ;; @note            Caller must pair with %destroy (or use with-array-ref) to avoid leaks
  ;; @note            Defined in lib/Bindings/Support/ArrayRef.cpp; struct in ArrayRef.h
  (define %make
    (foreign-procedure "mlir_support_array_ref_make" (uptr uptr) uptr))

  ;; @brief Free a CArrayRef previously allocated by %make.
  ;; @param ref  uptr — address returned by %make (mlir_support_array_ref_make)
  ;; @return     void
  ;; @note       Must not be called twice on the same pointer (double-free is UB)
  ;; @note       Defined in lib/Bindings/Support/ArrayRef.cpp
  (define %destroy
    (foreign-procedure "mlir_support_array_ref_destroy" (uptr) void))

  ) ;; end library (mlir support array-ref ffi)

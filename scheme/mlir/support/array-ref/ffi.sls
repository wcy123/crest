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
  (export %make %CrestObject::delete)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief Allocate a CArrayRef on the C heap and return its address as uptr.
  ;; @param data-ptr  uptr — pointer to the first element
  ;; @param size      uptr — number of elements
  ;; @return          uptr — address of newly allocated CArrayRef
  ;;                  Layout: { deletor@0, data@8, size@16 }
  ;; @note            Caller must call CrestObject::delete when done
  (define %make
    (foreign-procedure "mlir_support_array_ref_make" (uptr uptr) uptr))

  ;; @brief Call the deletor stored in a CrestObject, freeing it.
  ;; @param obj  uptr — address of any CrestObject (CArrayRef, etc.)
  ;; @note       Cannot be done from Scheme alone — needs C trampoline to
  ;;             dereference and call an arbitrary function pointer.
  (define %CrestObject::delete
    (foreign-procedure "CrestObject::delete" (uptr) void))

  ) ;; end library (mlir support array-ref ffi)

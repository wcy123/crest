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
  (export %crest::CArrayRef<uptr>?)
  (import (rnrs)
          (mlir support foreign) (only (chezscheme) foreign-procedure))

  ;; @brief Type predicates — is this CrestObject a CArrayRef<T>?
  ;; Returns 1 (true) or 0 (false). The isa logic (deletor comparison) is in C++.
  (define %crest::CArrayRef<uptr>?
    (crest-foreign-procedure "crest::CArrayRef<uptr>?" (uptr) int))

  ) ;; end library (mlir support array-ref ffi)

#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support array-ref ffi) — raw C bindings for CArrayRef lifecycle.
;;
;; % prefix = raw C binding. Prefer (mlir support array-ref) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support array-ref ffi)
  (export %make %destroy)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; Allocate a CArrayRef on the C heap.
  (define %make
    (foreign-procedure "mlir_support_array_ref_make" (uptr uptr) uptr))

  ;; Free a CArrayRef previously allocated by %make.
  (define %destroy
    (foreign-procedure "mlir_support_array_ref_destroy" (uptr) void))

) ;; end library (mlir support array-ref ffi)

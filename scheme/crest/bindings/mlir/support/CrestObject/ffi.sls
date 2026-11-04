#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;; Mirrors lib/Bindings/Support/CrestObject.h (CREST-specific, no MLIR counterpart).
;;===----------------------------------------------------------------------===;;
;;
;; (mlir support CrestObject ffi) — raw C binding for CrestObject.
;;
;; % prefix = raw C binding. Prefer (mlir support CrestObject) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir support CrestObject ffi)
  (export %CrestObject::delete)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief Call the deletor stored in a CrestObject, freeing it.
  (define %CrestObject::delete
    (foreign-procedure "CrestObject::delete" (uptr) void))

  ) ;; end library (mlir support CrestObject ffi)

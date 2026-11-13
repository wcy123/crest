#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;; Mirrors lib/Bindings/Support/CrestObject.h (CREST-specific, no MLIR counterpart).
;;===----------------------------------------------------------------------===;;
;;
;; (crest support CrestObject ffi) — raw C binding for CrestObject.
;;
;; % prefix = raw C binding. Prefer (crest support CrestObject) for normal use.
;;
;;===----------------------------------------------------------------------===;;

(library (crest support CrestObject ffi)
  (export %crest::CrestObject::delete)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief Call the deletor stored in a CrestObject, freeing it.
  (define %crest::CrestObject::delete
    (foreign-procedure "crest::CrestObject::delete" (uptr) void))

  ) ;; end library (crest support CrestObject ffi)

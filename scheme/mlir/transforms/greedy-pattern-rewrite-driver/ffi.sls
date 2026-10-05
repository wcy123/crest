#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir transforms greedy-pattern-rewrite-driver ffi) — raw C bindings.
;; Mirrors mlir/Transforms/GreedyPatternRewriteDriver.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir transforms greedy-pattern-rewrite-driver ffi)
  (export %greedy-pattern-rewrite-driver-apply)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  (define %greedy-pattern-rewrite-driver-apply
    (foreign-procedure
      "mlir_transforms_greedy_pattern_rewrite_driver_apply"
      (uptr uptr) int))

) ;; end library (mlir transforms greedy-pattern-rewrite-driver ffi)

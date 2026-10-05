#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir transforms greedy-pattern-rewrite-driver) — user-visible API.
;; Mirrors mlir/Transforms/GreedyPatternRewriteDriver.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir transforms greedy-pattern-rewrite-driver)
  (export greedy-pattern-rewrite-driver-apply)
  (import (rnrs) (mlir transforms greedy-pattern-rewrite-driver ffi))

  (define greedy-pattern-rewrite-driver-apply
    %greedy-pattern-rewrite-driver-apply)

) ;; end library (mlir transforms greedy-pattern-rewrite-driver)

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

  ;; @brief mlir::applyPatternsGreedily — repeatedly apply patterns to op and
  ;;        all nested ops in a greedy, worklist-driven fashion until a fixed
  ;;        point is reached or the iteration limit is hit.
  ;; @param op       Operation* uptr — root op to rewrite
  ;; @param patterns RewritePatternSet* uptr (consumed/moved)
  ;; @return         1 on success (fixed point reached), 0 on failure
  ;; @see   mlir/Transforms/GreedyPatternRewriteDriver.h
  ;; @note  Defined in lib/Bindings/Transforms/GreedyPatternRewriteDriver.cpp
  (define greedy-pattern-rewrite-driver-apply
    %greedy-pattern-rewrite-driver-apply)

) ;; end library (mlir transforms greedy-pattern-rewrite-driver)

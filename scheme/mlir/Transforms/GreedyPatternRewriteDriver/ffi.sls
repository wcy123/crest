#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir Transforms GreedyPatternRewriteDriver ffi) — raw C bindings.
;; Mirrors mlir/Transforms/GreedyPatternRewriteDriver.h.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir Transforms GreedyPatternRewriteDriver ffi)
  (export %mlir::applyPatternsGreedily)
  (import (rnrs) (only (chezscheme) foreign-procedure))

  ;; @brief mlir::applyPatternsGreedily — repeatedly apply patterns to op and
  ;;        all nested ops in a greedy, worklist-driven fashion until a fixed
  ;;        point is reached or the iteration limit is hit.
  ;; @param op       Operation* uptr — root op to rewrite
  ;; @param patterns RewritePatternSet* uptr (consumed/moved)
  ;; @return         1 on success (fixed point reached), 0 on failure
  ;; @see   mlir/Transforms/GreedyPatternRewriteDriver.h
  ;; @note  Defined in lib/Bindings/Transforms/GreedyPatternRewriteDriver.cpp
  (define %mlir::applyPatternsGreedily
    (foreign-procedure
     "mlir_transforms_greedy_pattern_rewrite_driver_apply"
     (uptr uptr) int))

  ) ;; end library (mlir Transforms GreedyPatternRewriteDriver ffi)

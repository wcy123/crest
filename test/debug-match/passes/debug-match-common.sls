#!r6rs
;; Shared helper for debug-match test passes.
(library (passes debug-match-common)
  (export make-pass-body)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern))

  ;; (make-pass-body root-op-name pattern) → pass-entry-point function
  ;; Registers pattern for root-op-name and runs the greedy rewriter.
  (define (make-pass-body root-op-name pattern)
    (lambda (module-op)
      (let ([ctx (mlir::Operation::getContext module-op)])
        (with-current-MLIRContext ctx
          (with-RewritePatternSet patterns (ctx
                                            :rewrite-patterns ((root-op-name pattern 1)))
            (mlir::applyPatternsGreedily module-op patterns))))))

  ) ;; end library

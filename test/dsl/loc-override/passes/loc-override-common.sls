#!r6rs
;; Shared helper for loc-override test pass.
(library (passes loc-override-common)
  (export make-pass-body)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern))

  (define (make-pass-body root-op-name pattern)
    (lambda (module-op)
      (let ([ctx (mlir::Operation::getContext module-op)])
        (with-current-MLIRContext ctx
          (with-RewritePatternSet patterns (ctx
                                            :rewrite-patterns ((root-op-name pattern 1)))
            (mlir::applyPatternsGreedily module-op patterns))))))

  ) ;; end library

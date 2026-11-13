#!r6rs
;; Rewrites test.src(%a, %b) into badr.op, whose inferReturnTypes raises an error, naming no result type.
(library (passes use-bad-raises)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%build op rewriter)
    :if-match
      test.src (%a %b)
    :rewrite op :with
      r = badr.op (%a)
      test.use (r))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.src" %%build 10)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

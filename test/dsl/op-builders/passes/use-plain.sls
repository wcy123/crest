#!r6rs
;; Rewrites test.src(%a, %b) into bld.plain, which has no :infer-result-types, and names no result type.
(library (passes use-plain)
  (export run-pass)
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
      r = bld.plain (%a)
      test.use (r))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx)
          (add-rewrite-pattern patterns "test.src" %%build 10)
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

#!r6rs
;; Rewrites test.src(%a, %b) into ops created without a result type, plus one with an explicit type.
(library (passes use-builder)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR BuiltinTypes) mlir::IntegerType::get<i64>)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%build op rewriter)
    :if-match
      test.src (%a %b)
    :rewrite op :with
      i64  = (mlir::IntegerType::get<i64>)
      sum  = bld.add (%a %b)
      zero = bld.zero ()
      wide = bld.add (%a %b) -> i64
      test.use (sum zero wide))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx)
          (add-rewrite-pattern patterns "test.src" %%build 10)
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

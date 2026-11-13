#!r6rs
;; Rewrites test.src(%a, %b) into ops created without a result type, plus one with an explicit type.
(library (passes use-builder)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%build op rewriter)
    :if-match
      test.src (%a %b)
    :rewrite op :with
      ty   = (mlir::Value::getType %a)
      sum  = bld.add (%a %b)
      zero = bld.zero ()
      same = bld.add (%a %b) -> ty
      test.use (sum zero same))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.src" %%build 10)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

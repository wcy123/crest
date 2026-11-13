#!r6rs
(library (passes unreachable)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (crest))

  (define-rewrite-pattern (%%p op rewriter)
    :if-match
      %out   = test.add (%x %y)
      %other = test.other (%z)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%x %y) -> !out-type)

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx :rewrite-patterns (("test.add" %%p 1)))
          (mlir::applyPatternsGreedily module-op patterns)))))
  ) ;; end library

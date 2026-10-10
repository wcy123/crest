#!r6rs
;; Test pass: exercises :check-eq debug output.
;; Pattern expects both operands of test.mul to be the same SSA value.
(library (passes debug-match-check-eq)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%pattern op rewriter)
    :if-match
      %out = test.mul (%shared %shared)
    :rewrite %out :with
      (%result = test.mul (%shared %shared) -> (mlir::Value::getType %out)))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
                                (with-RewritePatternSet (patterns ctx)
                                                        (add-rewrite-pattern patterns "test.mul" %%pattern 1)
                                                        (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

#!r6rs
;; Test pass: exercises :bind-operands + :check-where debug output.
;; Pattern expects test.sub with an optional second operand that must be present.
(library (passes debug-match-bind-operands)
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
      %out   = test.sub (%a (:optional %b))
        :where (not (unbound-value? %b))
      %chain = test.add (%out %out)
    :rewrite %chain :with
      (%result = test.add (%out %out) -> (mlir::Value::getType %chain)))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
                                (with-RewritePatternSet (patterns ctx)
                                                        (add-rewrite-pattern patterns "test.add" %%pattern 1)
                                                        (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

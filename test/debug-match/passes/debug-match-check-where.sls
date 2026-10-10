#!r6rs
;; Test pass: exercises :check-where debug output.
;; Pattern has a :where guard (getNumResults == 99) that always fails.
(library (passes debug-match-check-where)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType mlir::Value::getDefiningOp)
          (only (mlir IR Operation) mlir::Operation::getContext mlir::Operation::getNumResults)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%pattern op rewriter)
    :if-match
      %out = test.mul (%a %b)
        :where (eqv? (mlir::Operation::getNumResults (mlir::Value::getDefiningOp %a)) 99)
    :rewrite %out :with
      (%result = test.mul (%a %b) -> (mlir::Value::getType %out)))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
                                (with-RewritePatternSet (patterns ctx)
                                                        (add-rewrite-pattern patterns "test.mul" %%pattern 1)
                                                        (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

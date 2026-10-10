#!r6rs
;; Test pass: exercises :check-op debug output.
;; Registers a pattern expecting "test.add"; the test MLIR has "test.sub".
(library (passes debug-match-check-op)
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
      %out = test.add (%a %b)
    :rewrite %out :with
      (%result = test.add (%a %b) -> (mlir::Value::getType %out)))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
                                (with-RewritePatternSet (patterns ctx)
                                                        (add-rewrite-pattern patterns "test.sub" %%pattern 1)
                                                        (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

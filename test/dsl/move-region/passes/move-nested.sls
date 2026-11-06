#!r6rs
;; (:move-region op) inside a ^bb body: the rewriter is still reachable there, and the insertion
;; point is restored afterwards, so test.after lands after test.wrapper.
(library (passes move-nested)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%nested op rewriter)
    :if-match
      test.nested ()
    :rewrite op :with
      test.wrapper ()
      (^bb0 ()
            test.dst ()
            (:move-region op))
      test.after ())

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx)
          (add-rewrite-pattern patterns "test.nested" %%nested 10)
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

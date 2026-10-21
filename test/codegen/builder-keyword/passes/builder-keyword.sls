;; Test: :builder and (:arg N) work as proper macros outside begin-mlir-code DSL.
;; Pattern: test.copy(%v) → test.with_block(%v) where the block uses (:arg 0)
;; to access the block arg and passes :builder to a Scheme helper.
(library (passes builder-keyword)
  (export run-pass)
  (import (except (rnrs (6)) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver)
                mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  ;; Helper receives :builder — a real macro call, not a DSL form.
  (define (%%noop-with-builder! bldr) bldr)

  (define-rewrite-pattern (%%pattern op rewriter)
    :if-match
      %out = test.copy (%v)
    :then-let
      ([!t (mlir::Value::getType %v)]
       [arg-types (list !t)])
    :rewrite %out :with
      (%result = test.with_block (%v)
               (^bb0 ,@arg-types
                     ;; (:arg 0) and :builder used as real macros in Scheme context
                     (_ = (%%noop-with-builder! :builder))
                     (test.yield ((:arg 0))))
               -> !t))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet (ps ctx)
          (add-rewrite-pattern ps "test.copy" %%pattern 10)
          (mlir::applyPatternsGreedily module-op ps)))))

  ) ;; end library

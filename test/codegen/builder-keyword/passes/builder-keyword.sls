;; Test: :builder keyword binds the active rewriter/builder as a Scheme value.
;; Pattern: test.copy(%v) → test.identity(%v), using (b = :builder) then b.
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

  ;; Helper: verifies builder is a non-null Scheme value.
  (define (%%assert-builder-ok! bldr)
    (when (zero? bldr) (error 'builder-keyword "builder is null")))

  (define-rewrite-pattern (%%pattern op rewriter)
    :if-match
      %out = test.copy (%v)
    :then-let
      ([!t (mlir::Value::getType %v)])
    :rewrite %out :with
      ;; Bind :builder, verify it is non-null, then emit via implicit builder.
      (b   = :builder)
      (_   = (%%assert-builder-ok! b))
      (%result = test.identity (%v) -> !t))  ; different op — no infinite loop

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet (ps ctx)
          (add-rewrite-pattern ps "test.copy" %%pattern 10)
          (mlir::applyPatternsGreedily module-op ps)))))

  ) ;; end library

#!r6rs
;; Test: the attribute shorthands in a :rewrite :with body (here `:index`) need
;; (current-MLIRContext). run-pass does not install it (there is no
;; with-current-MLIRContext around the pattern driver); the generated pattern does.
(library (passes current-context)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  ;; test.in(%v) -> test.out(%v) {idx = 0 : index}
  (define-rewrite-pattern (%%rewrite op rewriter)
    :if-match
      %out = test.in (%v)
    :then-let
      ([!ty (mlir::Value::getType %v)])
    :rewrite %out :with
      result = test.out (%v) (idx : 0 :index) -> !ty)

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-RewritePatternSet patterns (ctx)
        (add-rewrite-pattern patterns "test.in" %%rewrite 1)
        (mlir::applyPatternsGreedily module-op patterns))))

  ) ;; end library

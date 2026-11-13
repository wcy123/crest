#!r6rs
;; A :where guard that has the text (:attr "k") inside a quote. It is data, not a use of :attr: the guard asks
;; whether the first element of that list is the symbol :attr, which it is only if the list was left alone.
(library (passes where-quote)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (crest))

  (define-rewrite-pattern (%%where-quote op rewriter)
    :if-match
      %out = test.add (%x %y)
        :where (eq? (car '(:attr "k")) ':attr)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = test.fused (%x %y) -> !out-type)

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx :rewrite-patterns (("test.add" %%where-quote 1)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

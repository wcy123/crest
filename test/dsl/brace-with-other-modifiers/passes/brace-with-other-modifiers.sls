#!chezscheme
;; Test: a { } keeps its place among the other modifiers of an op-form. The index of a region
;; counts the braces and the (:move-region ...) before it, and :loc after a brace still applies.
(library (passes brace-with-other-modifiers)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  ;; Region 0 is built, region 1 is moved from the matched op, region 2 is built.
  (define-rewrite-pattern (%%move_between_braces op rewriter)
    :if-match
      test.move_between_braces ()
    :rewrite op :with
      test.dst_move_between_braces ()
      { test.first () }
      (:move-region op)
      { test.last () })

  ;; The location written after the braces is the one of the new op.
  (define-rewrite-pattern (%%loc_after_braces op rewriter)
    :if-match
      test.loc_after_braces ()
    :rewrite op :with
      test.dst_loc_after_braces ()
      { test.inner () }
      { test.second () }
    :loc ("brace-loc.sls" 7 3))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.move_between_braces" %%move_between_braces 10)
                                                             ("test.loc_after_braces" %%loc_after_braces 10)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

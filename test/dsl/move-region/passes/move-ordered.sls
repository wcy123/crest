#!r6rs
;; (:move-region op 1) takes the second region of the source and keeps its position among the
;; other region modifiers: the new op gets a built region, then the moved one, then an empty one.
(library (passes move-ordered)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%ordered op rewriter)
    :if-match
      test.two ()
    :rewrite op :with
      test.dst ()
      (^bb0 () test.built ())
      (:move-region op 1)
      (:region))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.two" %%ordered 10)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

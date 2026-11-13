#!r6rs
;; Test: a (:region) modifier with no blocks reserves an empty region, in order among the
;; op's other regions. test.src becomes test.dst with three regions: empty, one block, empty.
(library (passes empty-region)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%empty op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      test.dst ()
      (:region)
      (^bb0 () test.one ())
      (:region))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.src" %%empty 10)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

#!r6rs
;; The same rewrite written with the DSL: (:move-region SRC-OP [IDX]) is a region modifier that
;; moves region IDX (default 0) of SRC-OP into the new op instead of creating new blocks.
(library (passes move-region)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%adopt op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      test.dst ()
      (:move-region op))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.src" %%adopt 10)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

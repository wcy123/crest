#!r6rs
;; A call after -> : a parenthesised form is a list of types, so (mlir::IndexType::get) is a
;; one-element list holding the procedure, not a call. Creating the op must say so.
(library (passes call-as-type)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR BuiltinTypes) mlir::IndexType::get)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%call-as-type op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      r = test.dst () -> (mlir::IndexType::get))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.src" %%call-as-type 10)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

#!r6rs
;; Result types after -> : a variable holding a type, and a parenthesised list of types for several
;; results. A call as the type is bound first (var = (expr)), as the manual says.
(library (passes result-type-forms)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR BuiltinTypes) mlir::IntegerType::get<i64> mlir::IndexType::get)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%types op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      i64 = (mlir::IntegerType::get<i64>)
      idx = (mlir::IndexType::get)
      a = test.one () -> i64
      (b c) = test.two () -> (i64 idx)
      test.use (a b c))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.src" %%types 10)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

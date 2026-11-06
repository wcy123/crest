#!r6rs
;; Every attribute shorthand of begin-mlir-code from the manual's table, with only (crest)
;; imported for the DSL keywords.
(library (passes attr-shorthands)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%shorthands op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      test.dst ()
      (s   : "text"     :string)
      (ix  : 7          :index)
      (i8  : 1          :i8)
      (i16 : 2          :i16)
      (i32 : 3          :i32)
      (i64 : 4          :i64)
      (f32 : 0.5        :f32)
      (f64 : 0.25       :f64)
      (a8  : '(1 2)     :i8-array)
      (a16 : '(3 4)     :i16-array)
      (a32 : '(5 6)     :i32-array)
      (a64 : '(7 8)     :i64-array)
      (u   : #f         :unit))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx)
          (add-rewrite-pattern patterns "test.src" %%shorthands 10)
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

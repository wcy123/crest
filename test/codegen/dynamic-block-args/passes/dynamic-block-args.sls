#!r6rs
;; Test: ,@pairs-expr dynamic block arguments and (:arg N) shorthand in begin-mlir-code.
;;
;; Rewrites test.copy(%v) → test.with_block(%v) {
;;   ^bb0(%arg: <type of %v>):
;;     test.yield %arg
;; }
;;
;; The block arg type is determined at runtime from %v's type.
(library (passes dynamic-block-args)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver)
                mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%pattern op rewriter)
    :if-match
      %out = test.copy (%v)
    :then-let
      ([!vtype   (mlir::Value::getType %v)]
       ;; Build type list at runtime: one type per block arg.
       [arg-types (list !vtype)])
    :rewrite %out :with
      result = test.with_block (%v)
      (^bb0 ,@arg-types
            test.yield ((:arg 0)))
      -> !vtype) ;

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet (patterns ctx)
          (add-rewrite-pattern patterns "test.copy" %%pattern 10)
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

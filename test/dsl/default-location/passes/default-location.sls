#!r6rs
;; Test: the location of an op emitted by a lowering pattern.
;;
;; Rewrites test.in (at a user source location) to test.out with no :loc. The emitted
;; op should carry the location of the op it replaces, as a C++ lowering does with
;; op->getLoc(). Today it carries the Scheme source position of the op-form in this file.
(library (passes default-location)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%rewrite op rewriter)
    :if-match
      %out = test.in (%v)
    :then-let
      ([!ty (mlir::Value::getType %v)])
    :rewrite %out :with
      result = test.out (%v) -> !ty)

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx)
          (add-rewrite-pattern patterns "test.in" %%rewrite 1)
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

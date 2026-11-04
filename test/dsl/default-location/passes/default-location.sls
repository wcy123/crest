#!r6rs
;; Test: the location of an op emitted by a pass.
;;
;; Without :loc, an op carries the Scheme source position of its op-form in this file, so a
;; diagnostic resolves to the pass line that created it. With an explicit :loc, it carries
;; that location (here the location of the op being replaced).
(library (passes default-location)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext mlir::Operation::getLoc)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  ;; No :loc: the emitted op carries this file's position.
  (define-rewrite-pattern (%%default op rewriter)
    :if-match
      %out = test.in (%v)
    :then-let
      ([!ty (mlir::Value::getType %v)])
    :rewrite %out :with
      result = test.out (%v) -> !ty)

  ;; Explicit :loc: the emitted op carries the location of the op it replaces.
  (define-rewrite-pattern (%%explicit op rewriter)
    :if-match
      %out = test.in2 (%v)
    :then-let
      ([!ty (mlir::Value::getType %v)]
       [user-loc (mlir::Operation::getLoc op)])
    :rewrite %out :with
      result = test.out2 (%v) -> !ty
    :loc user-loc)

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx)
          (add-rewrite-pattern patterns "test.in" %%default 1)
          (add-rewrite-pattern patterns "test.in2" %%explicit 1)
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

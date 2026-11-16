#!chezscheme
;; Test: { ... } is one region in a begin-mlir-code op-form, as in the generic form of MLIR.
;; The file starts with #!chezscheme: the reader of #!r6rs, which a .sls file gets by default,
;; rejects the brace. A block that no branch reaches is erased by the greedy driver, so the
;; multi-block cases are in test/dsl/brace-blocks, which uses the conversion driver.
(library (passes brace-regions)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Value) mlir::Value::getType)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  ;; Two regions, one entry block each, without a label.
  (define-rewrite-pattern (%%two op rewriter)
    :if-match
      test.two ()
    :rewrite op :with
      test.dst_two ()
      { test.a () }
      { test.b () })

  ;; Static block arguments.
  (define-rewrite-pattern (%%static op rewriter)
    :if-match
      %out = test.static (%v)
    :then-let
      ([!vtype (mlir::Value::getType %v)])
    :rewrite %out :with
      result = test.dst_static (%v)
      { ^entry ((x : !vtype))
        test.yield (x) }
      -> !vtype)

  ;; Dynamic block arguments, read with (:arg N).
  (define-rewrite-pattern (%%dynamic op rewriter)
    :if-match
      %out = test.dynamic (%v)
    :then-let
      ([!vtype (mlir::Value::getType %v)]
       [arg-types (list !vtype)])
    :rewrite %out :with
      result = test.dst_dynamic (%v)
      { ^entry ,@arg-types
        test.yield ((:arg 0)) }
      -> !vtype)

  ;; A brace inside the body of a block belongs to the op written there.
  (define-rewrite-pattern (%%nested op rewriter)
    :if-match
      test.nested ()
    :rewrite op :with
      test.outer ()
      { test.inner ()
        { test.leaf () }
        test.after () })

  ;; An empty brace is a region without blocks; the order of the regions is kept.
  (define-rewrite-pattern (%%empty op rewriter)
    :if-match
      test.empty ()
    :rewrite op :with
      test.dst_empty ()
      { }
      { test.one () }
      { })

  ;; Braces and the older forms mix, and each is one region in order.
  (define-rewrite-pattern (%%mixed op rewriter)
    :if-match
      test.mixed ()
    :rewrite op :with
      test.dst_mixed ()
      (^bb0 () test.old ())
      { test.new () }
      (:region))

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.two" %%two 10)
                                                             ("test.static" %%static 10)
                                                             ("test.dynamic" %%dynamic 10)
                                                             ("test.nested" %%nested 10)
                                                             ("test.empty" %%empty 10)
                                                             ("test.mixed" %%mixed 10)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

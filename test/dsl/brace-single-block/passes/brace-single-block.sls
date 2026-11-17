#!chezscheme
;; Test: { ... } is one region in a begin-mlir-code op-form, as in the generic form of MLIR.
;; The file starts with #!chezscheme: the reader of #!r6rs, which a .sls file gets by default,
;; rejects the brace. A block that no branch reaches is erased by the greedy driver, so the
;; multi-block cases are in test/dsl/brace-multi-block, which uses the conversion driver.
(library (passes brace-single-block)
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
  (define-rewrite-pattern (%%many_regions_one_block op rewriter)
    :if-match
      test.many_regions_one_block ()
    :rewrite op :with
      test.dst_many_regions_one_block ()
      { test.a () }
      { test.b () })

  ;; Static block arguments.
  (define-rewrite-pattern (%%one_region_static_arguments op rewriter)
    :if-match
      %out = test.one_region_static_arguments (%v)
    :then-let
      ([!vtype (mlir::Value::getType %v)])
    :rewrite %out :with
      result = test.dst_one_region_static_arguments (%v)
      { ^entry ((x : !vtype))
        test.yield (x) }
      -> !vtype)

  ;; Dynamic block arguments, read with (:arg N).
  (define-rewrite-pattern (%%one_region_dynamic_arguments op rewriter)
    :if-match
      %out = test.one_region_dynamic_arguments (%v)
    :then-let
      ([!vtype (mlir::Value::getType %v)]
       [arg-types (list !vtype)])
    :rewrite %out :with
      result = test.dst_one_region_dynamic_arguments (%v)
      { ^entry ,@arg-types
        test.yield ((:arg 0)) }
      -> !vtype)

  ;; A brace inside the body of a block belongs to the op written there.
  (define-rewrite-pattern (%%nested_braces op rewriter)
    :if-match
      test.nested_braces ()
    :rewrite op :with
      test.outer ()
      { test.inner ()
        { test.leaf () }
        test.after () })

  ;; An empty brace is a region without blocks; the order of the regions is kept.
  (define-rewrite-pattern (%%empty_region op rewriter)
    :if-match
      test.empty_region ()
    :rewrite op :with
      test.dst_empty_region ()
      { }
      { test.one () }
      { })

  ;; A block with a label and no ops is a block without ops: the body of a block may be empty.
  (define-rewrite-pattern (%%one_region_empty_block op rewriter)
    :if-match
      test.one_region_empty_block ()
    :rewrite op :with
      test.dst_one_region_empty_block ()
      { ^only () })

  ;; A block with arguments and no ops, with static and with dynamic arguments: the arguments
  ;; are still created.
  (define-rewrite-pattern (%%empty_block_with_arguments op rewriter)
    :if-match
      %out = test.empty_block_with_arguments (%v)
    :then-let
      ([!vtype (mlir::Value::getType %v)]
       [arg-types (list !vtype)])
    :rewrite %out :with
      result = test.dst_empty_block_with_arguments (%v)
      { ^static ((x : !vtype)) }
      { ^dynamic ,@arg-types }
      -> !vtype)

  ;; Braces and attribute modifiers mix in any order; each brace is one region, in order.
  (define-rewrite-pattern (%%braces_among_attributes op rewriter)
    :if-match
      test.braces_among_attributes ()
    :rewrite op :with
      test.dst_braces_among_attributes ()
      (first : "a" :string)
      { test.one () }
      (second : 7 :index)
      { test.two () })

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.many_regions_one_block" %%many_regions_one_block 10)
                                                             ("test.one_region_static_arguments" %%one_region_static_arguments 10)
                                                             ("test.one_region_dynamic_arguments" %%one_region_dynamic_arguments 10)
                                                             ("test.nested_braces" %%nested_braces 10)
                                                             ("test.empty_region" %%empty_region 10)
                                                             ("test.one_region_empty_block" %%one_region_empty_block 10)
                                                             ("test.empty_block_with_arguments" %%empty_block_with_arguments 10)
                                                             ("test.braces_among_attributes" %%braces_among_attributes 10)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

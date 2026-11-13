#!r6rs
;; Test: ops created in a region body by begin-mlir-code inside a greedy rewrite pattern are
;; reported to the driver.
;;
;;   test.src   -->  test.wrapper { ^bb0: test.inner }
;;   test.inner -->  test.done
(library (passes region-in-greedy)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver)
                mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%wrap op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      test.wrapper ()
      (^bb0 ()
            test.inner ()))

  (define-rewrite-pattern (%%inner->done op rewriter)
    :if-match
      test.inner ()
    :rewrite op :with
      test.done ())

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.src" %%wrap 10)
                                                             ("test.inner" %%inner->done 10)))
          (mlir::applyPatternsGreedily module-op patterns)))))

  ) ;; end library

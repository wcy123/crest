#!r6rs
;; The control: greedy rewrite patterns registered with the low-level API, as every rewrite pass
;; does today (compare toy:add-canonicalization-patterns! in samples/toy/ch3/combine.sls).
;;
;;   test.a   benefit 10        --> test.a_done
;;   test.b   default benefit   --> test.b_done
;;   test.c   added by hand, as a :populate hook does --> test.c_done
;;   test.x   two patterns, benefit 1 and 5: the higher benefit wins --> test.x_high
;;   other.y  no pattern: kept
(library (passes imperative)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (only (mlir Transforms GreedyPatternRewriteDriver) mlir::applyPatternsGreedily)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest))

  (define-rewrite-pattern (%%a op rewriter)
    :if-match
      test.a ()
    :rewrite op :with
      test.a_done ())

  (define-rewrite-pattern (%%b op rewriter)
    :if-match
      test.b ()
    :rewrite op :with
      test.b_done ())

  (define-rewrite-pattern (%%c op rewriter)
    :if-match
      test.c ()
    :rewrite op :with
      test.c_done ())

  (define-rewrite-pattern (%%x-low op rewriter)
    :if-match
      test.x ()
    :rewrite op :with
      test.x_low ())

  (define-rewrite-pattern (%%x-high op rewriter)
    :if-match
      test.x ()
    :rewrite op :with
      test.x_high ())

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-RewritePatternSet patterns (ctx
                                          :rewrite-patterns (("test.a" %%a 10)
                                                             ("test.b" %%b 1)
                                                             ("test.x" %%x-low 1)
                                                             ("test.x" %%x-high 5)
                                                             ("test.c" %%c 1)))
          (eqv? 1 (mlir::applyPatternsGreedily module-op patterns))))))

  ) ;; end library

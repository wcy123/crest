#!r6rs
;; (:move-region op) inside a conversion pattern: the moved blocks are reported to the
;; conversion driver, so test.inner inside the moved body is still legalized.
;;
;;   test.src   -->  test.dst, body moved
;;   test.inner -->  test.done
;;   test.nested -->  test.wrapper { test.dst, body moved } then test.after (move inside a ^bb body)
(library (passes move-conversion)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
          (only (mlir IR PatternMatch) with-RewritePatternSet)
          (mlir Transforms DialectConversion)
          (crest))

  (define-conversion-pattern (%%move op operands-ref rw tc)
    :if-match
      test.src ()
    :rewrite op :with
      test.dst ()
      (:move-region op))

  (define-conversion-pattern (%%nested op operands-ref rw tc)
    :if-match
      test.nested ()
    :rewrite op :with
      test.wrapper ()
      (^bb0 ()
            test.dst ()
            (:move-region op))
      test.after ())

  (define-conversion-pattern (%%inner->done op operands-ref rw tc)
    :if-match
      test.inner ()
    :rewrite op :with
      test.done ())

  (define-pass-entry-point (module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-ConversionTarget target (ctx
                                       :dynamically-legal (("test.src" (lambda (op) #f))
                                                           ("test.inner" (lambda (op) #f))
                                                           ("test.nested" (lambda (op) #f)))
                                       :unknown-legal (lambda (op) #t))
          (with-RewritePatternSet patterns (ctx
                                            :conversion-patterns/ctx (("test.src" %%move 1)
                                                                      ("test.nested" %%nested 1)
                                                                      ("test.inner" %%inner->done 1)))
            (apply-full-conversion module-op target patterns))))))

  ) ;; end library

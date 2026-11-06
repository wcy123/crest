#!r6rs
;; (:move-region op) inside a conversion pattern: the moved blocks are reported to the
;; conversion driver, so test.inner inside the moved body is still legalized.
;;
;;   test.src   -->  test.dst, body moved
;;   test.inner -->  test.done
(library (passes move-conversion)
  (export run-pass)
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

  (define-conversion-pattern (%%inner->done op operands-ref rw tc)
    :if-match
      test.inner ()
    :rewrite op :with
      test.done ())

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (with-ConversionTarget target (ctx)
          (target-add-dynamically-legal-op target ctx "test.src" (lambda (op) #f))
          (target-add-dynamically-legal-op target ctx "test.inner" (lambda (op) #f))
          (target-mark-unknown-ops-dynamically-legal target (lambda (op) #t))
          (with-RewritePatternSet patterns (ctx)
            (add-conversion-pattern/ctx patterns "test.src" %%move 1)
            (add-conversion-pattern/ctx patterns "test.inner" %%inner->done 1)
            (apply-full-conversion module-op target patterns))))))

  ) ;; end library

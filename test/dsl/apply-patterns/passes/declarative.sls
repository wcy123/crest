#!r6rs
;; The same rewrite written with apply-patterns.
(library (passes declarative)
  (export run-pass)
  (import (except (rnrs) =)
          (only (crest callback) define-c-callable)
          (only (mlir IR PatternMatch) rewrite-pattern->c)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
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

  (define-c-callable %%c-callable (uptr uptr) int (rewrite-pattern->c %%c))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-patterns module-op ctx
                        :patterns (("test.a" %%a 10)
                                   ("test.b" %%b)
                                   ("test.x" %%x-low 1)
                                   ("test.x" %%x-high 5))
                        :populate (lambda (patterns)
                                    (add-rewrite-pattern patterns "test.c" %%c-callable 1))))))

  ) ;; end library

#!r6rs
;; The same rewrite with define-pattern-set: the registration table is a procedure defined next to
;; the patterns, and the pass says :populate with one set or a list of sets.
(library (passes pattern-set)
  (export run-pass)
  (import (except (rnrs) =)
          (only (mlir IR Operation) mlir::Operation::getContext)
          (only (mlir IR MLIRContext) with-current-MLIRContext)
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

  (define-pattern-set first-patterns
    ("test.a" %%a 10)
    ("test.b" %%b))

  (define-pattern-set second-patterns
    ("test.x" %%x-low 1)
    ("test.x" %%x-high 5)
    ("test.c" %%c))

  (define (run-pass module-op)
    (let ([ctx (mlir::Operation::getContext module-op)])
      (with-current-MLIRContext ctx
        (apply-patterns module-op ctx
                        :populate (list first-patterns second-patterns)))))

  ) ;; end library

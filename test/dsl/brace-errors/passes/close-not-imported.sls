#!chezscheme
;; A file that imports { but not } gets an error that says } is not the keyword, not an error
;; that the { has no matching }. The { is written |{|, the same symbol, for the commit hook.
(library (passes close-not-imported)
  (export pass-entry-point)
  (import (except (rnrs) =)
          (only (crest) define-pass-entry-point)
          (only (crest pattern-dsl rewrite) begin-mlir-code)
          (only (crest pattern-dsl keywords) = : -> |{|))

  (define (%%build)
    (begin-mlir-code
        test.dst ()
        { test.a () }
        -> ()))

  (define-pass-entry-point (module-op) module-op)

  ) ;; end library

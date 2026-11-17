#!chezscheme
;; A { inside a block, with no } for it or for the outer {, is an error of expansion. Both braces
;; are written |{|, the same symbol, because the indenter of the commit hook counts a brace as a
;; bracket.
(library (passes nested-missing-close)
  (export pass-entry-point)
  (import (except (rnrs) =) (crest))

  (define-rewrite-pattern (%%p op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      test.dst ()
      |{| test.a ()
      |{| test.b ())

  (define-pass-entry-point (module-op) module-op)

  ) ;; end library

#!chezscheme
;; A ^label that is the last item of its brace has no arguments after it.
(library (passes label-at-end)
  (export pass-entry-point)
  (import (except (rnrs) =) (crest))

  (define-rewrite-pattern (%%p op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      test.dst ()
      { ^entry })

  (define-pass-entry-point (module-op) module-op)

  ) ;; end library

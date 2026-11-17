#!chezscheme
;; The item after a ^label is a list but not an argument list: ((name : type) ...) or ,@types.
(library (passes label-with-bad-arguments)
  (export pass-entry-point)
  (import (except (rnrs) =) (crest))

  (define-rewrite-pattern (%%p op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      test.dst ()
      { ^entry (test.a ())
        test.b () })

  (define-pass-entry-point (module-op) module-op)

  ) ;; end library

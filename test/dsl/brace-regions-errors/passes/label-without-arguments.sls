#!chezscheme
;; A ^label inside { } is followed by its arguments, ((name : type) ...) or ,@types.
(library (passes label-without-arguments)
  (export pass-entry-point)
  (import (except (rnrs) =) (crest))

  (define-rewrite-pattern (%%p op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      test.dst ()
      { ^entry
        test.a () })

  (define-pass-entry-point (module-op) module-op)

  ) ;; end library

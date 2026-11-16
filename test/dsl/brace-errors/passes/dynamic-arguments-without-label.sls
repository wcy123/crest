#!chezscheme
;; ,@types are the arguments of a block, and a block with arguments has a label.
(library (passes dynamic-arguments-without-label)
  (export pass-entry-point)
  (import (except (rnrs) =) (crest))

  (define-rewrite-pattern (%%p op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      test.dst ()
      { ,@(list) test.a () })

  (define-pass-entry-point (module-op) module-op)

  ) ;; end library

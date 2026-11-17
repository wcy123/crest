#!r6rs
;; (^label ...) was a region before braces. Now it is an error that says what to write.
(library (passes old-label-form)
  (export pass-entry-point)
  (import (except (rnrs) =) (crest))

  (define-rewrite-pattern (%%p op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      test.dst ()
      (^bb0 () test.a ()))

  (define-pass-entry-point (module-op) module-op)

  ) ;; end library

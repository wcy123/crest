#!chezscheme
;; A } without its { is an error of expansion, not a call of an unbound name. The brace without a
;; partner is written |}|, the same symbol, because the indenter of the commit hook counts a brace
;; as a bracket.
(library (passes stray-close)
  (export pass-entry-point)
  (import (except (rnrs) =) (crest))

  (define-rewrite-pattern (%%p op rewriter)
    :if-match
      test.src ()
    :rewrite op :with
      test.dst ()
      { test.a () }
      |}|)

  (define-pass-entry-point (module-op) module-op)

  ) ;; end library

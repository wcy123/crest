#!r6rs
;; A Scheme dialect whose op brings its own canonicalization pattern: neg(neg(x)) is x.
(library (passes canon-ops)
  (export oc)
  (import (except (rnrs) =)
          (only (chezscheme) command-line-arguments)
          (mlir IR Value)
          (only (mlir Transforms DialectConversion) add-rewrite-pattern)
          (crest dialect)
          (except (crest) :optional :variadic))

  (define-rewrite-pattern (%%neg-neg op rewriter)
    :if-match
      %inner = oc.neg (%x)
      %out   = oc.neg (%inner)
    :rewrite %out :with
      %x)

  (define-dialect oc
    (define-op neg
      :operands ((x mlir::Value?))
      :results  ((out mlir::Value?))
      :traits   (pure)
      (:get-canonicalization-patterns (patterns)
        (add-rewrite-pattern patterns "oc.neg" %%neg-neg 1)))))

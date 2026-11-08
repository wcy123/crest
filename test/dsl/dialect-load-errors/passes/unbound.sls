#!r6rs
;; The library does not compile: an op field names a predicate that does not exist.
(library (passes unbound)
  (export bad)
  (import (except (chezscheme) =) (crest dialect) (mlir IR Value))
  (define-dialect bad
    (define-op op :operands ((a this-predicate-is-not-bound)))))

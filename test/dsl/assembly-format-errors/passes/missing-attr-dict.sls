#!r6rs
(library (passes missing-attr-dict)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define (%%any-type? type) #t)

  (define-dialect bad
    (define-op op
      :operands ((input mlir::Value?))
      :results ((out %%any-type?))
      :assembly-format "$input `:` type($input) `to` type($out)")))

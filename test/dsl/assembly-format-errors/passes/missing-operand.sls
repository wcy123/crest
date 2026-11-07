#!r6rs
(library (passes missing-operand)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define (%%any-type? type) #t)

  (define-dialect bad
    (define-op op
      :operands ((input mlir::Value?) (other mlir::Value?))
      :results ((out %%any-type?))
      :assembly-format "$input attr-dict `:` type($input) `,` type($other) `->` type($out)")))

#!r6rs
(library (passes optional-attribute)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define (%%any-type? type) #t)
  (define (%%any-attr? attr) #t)

  (define-dialect bad
    (define-op op
      :operands ((input mlir::Value?))
      :attributes ((note %%any-attr? :optional))
      :results ((out %%any-type?))
      :assembly-format "$input `,` $note attr-dict `:` type($input) `to` type($out)")))

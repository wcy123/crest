#!r6rs
(library (passes repeated-attribute)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define (%%any-type? type) #t)
  (define (%%any-attr? attr) #t)

  (define-dialect bad
    (define-op op
      :operands ((input mlir::Value?))
      :attributes ((note %%any-attr?))
      :results ((out %%any-type?))
      :assembly-format "$note `,` $note $input attr-dict `:` type($input) `to` type($out)")))

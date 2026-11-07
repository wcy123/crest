#!r6rs
(library (passes operand-in-group)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define (%%any-type? type) #t)
  (define (%%any-attr? attr) #t)

  (define-dialect bad
    (define-op op
      :operands ((input mlir::Value? :optional) (other mlir::Value?))
      :results ((out %%any-type?))
      :assembly-format "($input^ $other `:` type($input) `,` type($other))? attr-dict `to` type($out)")))

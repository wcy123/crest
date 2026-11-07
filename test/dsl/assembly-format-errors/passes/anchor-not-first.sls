#!r6rs
(library (passes anchor-not-first)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define (%%any-type? type) #t)
  (define (%%any-attr? attr) #t)

  (define-dialect bad
    (define-op op
      :operands ((input mlir::Value? :optional))
      :attributes ((note %%any-attr?))
      :results ((out %%any-type?))
      :assembly-format "($input^ `,` $note^ `:` type($input))? attr-dict `to` type($out)")))

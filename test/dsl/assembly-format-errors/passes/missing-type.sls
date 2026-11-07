#!r6rs
(library (passes missing-type)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define (%%any-type? type) #t)

  (define-dialect bad
    (define-op op
      :operands ((input mlir::Value?))
      :results ((out %%any-type?))
      :assembly-format "$input attr-dict `to` type($out)")))

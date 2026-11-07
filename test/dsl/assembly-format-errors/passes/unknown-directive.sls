#!r6rs
(library (passes unknown-directive)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define (%%any-type? type) #t)

  (define-dialect bad
    (define-op op
      :operands ((input mlir::Value?))
      :results ((out %%any-type?))
      :assembly-format "$input foo attr-dict `:` type($input) `to` type($out)")))

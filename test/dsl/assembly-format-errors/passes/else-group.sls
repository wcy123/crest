#!r6rs
(library (passes else-group)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define (%%any-type? type) #t)

  (define-dialect bad
    (define-op op
      :operands ((input mlir::Value? :optional))
      :results ((out %%any-type?))
      :assembly-format "($input^ `:` type($input)):(`none`)? attr-dict `to` type($out)")))

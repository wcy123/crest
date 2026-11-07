#!r6rs
(library (passes unsupported-directive)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define (%%any-type? type) #t)

  (define-dialect bad
    (define-op op
      :operands ((input mlir::Value?))
      :results ((out %%any-type?))
      :assembly-format "custom<Foo>($input) attr-dict `:` type($input) `to` type($out)")))

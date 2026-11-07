#!r6rs
(library (passes with-parse)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define-dialect bad
    (define-op op
      :operands ((input mlir::Value?))
      :assembly-format "$input attr-dict `:` type($input)"
      (:parse (parser state) #t))))

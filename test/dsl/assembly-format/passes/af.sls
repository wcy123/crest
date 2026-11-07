#!r6rs
;; A Scheme dialect whose ops are written with :assembly-format only.
(library (passes af)
  (export af)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define (%%any-type? type) #t)
  (define (%%any-attr? attr) #t)

  (define-dialect af
    (define-op unary
      :operands ((input mlir::Value?))
      :results  ((out %%any-type?))
      :assembly-format "$input attr-dict `:` type($input) `to` type($out)")
    (define-op wrap
      :operands ((input mlir::Value?))
      :results  ((out %%any-type?))
      :assembly-format "`(` $input `:` type($input) `)` attr-dict `to` type(results)")
    (define-op plus
      :operands ((lhs mlir::Value?) (rhs mlir::Value?))
      :results  ((out %%any-type?))
      :assembly-format "$lhs `,` $rhs attr-dict `:` type($lhs) `,` type($rhs) `->` type($out)")
    (define-op call
      :attributes ((callee %%any-attr?))
      :operands   ((inputs mlir::Value? :variadic))
      :results    ((out %%any-type?))
      :assembly-format "$callee `(` $inputs `)` attr-dict `:` functional-type($inputs, results)")
    (define-op all
      :operands ((a mlir::Value?) (b mlir::Value?))
      :results  ((out %%any-type?))
      :assembly-format "`(` operands `)` attr-dict `:` functional-type(operands, results)")
    (define-op ret
      :operands ((value mlir::Value? :optional))
      :assembly-format "($value^ `:` type($value))? attr-dict")
    (define-op index
      :operands   ((input mlir::Value?))
      :attributes ((index %%any-attr?))
      :results    ((out %%any-type?))
      :assembly-format "$input `[` $index `]` attr-dict `:` type($input) `->` type($out)")
    (define-op two_attrs
      :attributes ((x %%any-attr?) (y %%any-attr?))
      :assembly-format "$x `,` $y attr-dict")
    (define-op box
      :operands ((input mlir::Value?))
      :assembly-format "`<` $input `:` type($input) `>` attr-dict")
    (define-op with
      :operands ((input mlir::Value?))
      :assembly-format "`with` $input attr-dict `:` type($input)")))

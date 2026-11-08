#!r6rs
;; A dialect whose attributes have a buildable type, as ODS I64Attr, F32Attr and IndexAttr do: the
;; text of the op leaves the type out and the parser builds the attribute with it.
(library (passes ta)
  (export ta)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value))

  (define (%%any-type? type) #t)
  (define (%%any-attr? attr) #t)

  (define-dialect ta
    (define-op index
      :operands   ((input mlir::Value?))
      :attributes ((index %%any-attr? :buildable-type :i64))
      :results    ((out %%any-type?))
      :assembly-format "$input `[` $index `]` attr-dict `:` type($input) `->` type($out)")

    (define-op scale
      :operands   ((input mlir::Value?))
      :attributes ((factor %%any-attr? :buildable-type :f32))
      :results    ((out %%any-type?))
      :assembly-format "$input `by` $factor attr-dict `:` type($input) `->` type($out)")

    (define-op at
      :operands   ((input mlir::Value?))
      :attributes ((position %%any-attr? :buildable-type :index))
      :results    ((out %%any-type?))
      :assembly-format "$input `at` $position attr-dict `:` type($input) `->` type($out)")))

#!r6rs
;; A Scheme dialect for the trait tests: one op per trait.
(library (passes trait-ops)
  (export pt)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Value))

  (define-dialect pt
    (define-op pure
      :summary  "pure: removed when dead, merged when repeated"
      :operands ((x mlir::Value?))
      :results  ((out mlir::Value?))
      :traits   (pure))
    (define-op impure
      :summary  "no traits: has unknown effects"
      :operands ((x mlir::Value?))
      :results  ((out mlir::Value?)))
    (define-op parent
      :summary "holds a region"
      :traits  (no-terminator))
    (define-op child
      :summary "only valid inside pt.parent"
      :traits  ((has-parent "pt.parent")))
    (define-op island
      :summary "a region closed to values from above"
      :traits  (isolated-from-above no-terminator))
    (define-op use
      :summary  "uses a value"
      :operands ((x mlir::Value?)))
    (define-op same-shape
      :summary  "operand and result have the same shape"
      :operands ((x mlir::Value?))
      :results  ((out mlir::Value?))
      :traits   (same-operands-and-result-shape))
    (define-op constant
      :summary "a constant"
      :results ((out mlir::Value?))
      :traits  (pure constant-like))))

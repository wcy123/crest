#!r6rs
;; A Scheme dialect for the op-builders tests. The :infer-result-types clause answers the result
;; types of an op that is created without `-> type`; it gets the operands (a list of Values) and the
;; attributes (an alist of name and Attribute) and returns one mlir::Type per result.
(library (passes bld-dialect)
  (export bld)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (mlir IR BuiltinTypes))

  (define-dialect bld
    ;; The result has the type of the left operand.
    (define-op add
      :operands ((lhs mlir::Value?) (rhs mlir::Value?))
      :results  ((out mlir::Value?))
      (:infer-result-types (operands attributes)
                           (list (mlir::Value::getType (car operands)))))

    ;; No operands: the answer comes from nothing but the op itself.
    (define-op zero
      :results ((out mlir::Value?))
      (:infer-result-types (operands attributes)
                           (list (mlir::IntegerType::get<i64>))))

    ;; No :infer-result-types: creating it without `-> type` is an error.
    (define-op plain
      :operands ((x mlir::Value?))
      :results  ((out mlir::Value?)))))

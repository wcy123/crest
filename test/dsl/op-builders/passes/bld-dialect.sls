#!r6rs
;; A Scheme dialect for the op-builders tests. An op that implements mlir::InferTypeOpInterface can
;; be created without `-> type`. The inferReturnTypes clause gets the context, the location (or #f),
;; the operands (a list of Values) and the attributes (an alist of name and Attribute), and returns
;; one mlir::Type per result.
(library (passes bld-dialect)
  (export bld)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (mlir IR BuiltinTypes)
          (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface))

  (define-dialect bld
    ;; The result has the type of the left operand.
    (define-op add
      :operands ((lhs mlir::Value?) (rhs mlir::Value?))
      :results  ((out mlir::Value?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (list (mlir::Value::getType (car operands)))))))

    ;; No operands: the answer comes from nothing but the op itself.
    (define-op zero
      :results ((out mlir::Value?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (list (mlir::IntegerType::get<i64>))))))

    ;; The inference is i32 and the result may be any single type: isCompatibleReturnTypes says what
    ;; fits, as the ODS ops of C++ that override it do (Toy: tensor<*xf64>, then a ranked tensor).
    (define-op loose
      :operands   ((x mlir::Value?))
      :results    ((out mlir::Value?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (list (mlir::Value::getType (car operands))))
                    (isCompatibleReturnTypes (inferred actual)
                                             (eqv? (length actual) 1)))))

    ;; refineReturnTypes says what the result may be, given the result types the op has (a list of
    ;; Types): any single type but i64 (unittests/Crest/InferTypeTest.cpp calls it).
    (define-op refined
      :operands   ((x mlir::Value?))
      :results    ((out mlir::Value?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (list (mlir::Value::getType (car operands))))
                    (refineReturnTypes (context location operands attributes return-types)
                                       (and (eqv? (length return-types) 1)
                                            (not (eqv? (car return-types) (mlir::IntegerType::get<i64>)))
                                            return-types)))))

    ;; No InferTypeOpInterface: creating it without `-> type` is an error.
    (define-op plain
      :operands ((x mlir::Value?))
      :results  ((out mlir::Value?)))))

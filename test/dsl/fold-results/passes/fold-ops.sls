#!r6rs
;; A Scheme dialect whose ops have folders that return results.
(library (passes fold-ops)
  (export fd)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (mlir IR Operation)
          (mlir IR BuiltinAttributes)
          (mlir IR Builders)
          (mlir IR MLIRContext)
          (only (crest pattern-dsl rewrite) begin-mlir-code)
          (only (crest pattern-dsl keywords) = : -> :loc))

  (define-dialect fd
    (:materialize-constant (builder value type loc)
      (with-current-OpBuilder builder
        (mlir::Value::getDefiningOp
         (begin-mlir-code
             r = fd.const () (value : value) :loc loc -> type))))

    ;; A constant: folds to its own value attribute, which is what makes it a constant.
    (define-op const
      :attributes ((value mlir::Value?))
      :results    ((out mlir::Value?))
      :traits     (pure constant-like)
      (:fold (op operand-attributes)
        (list (fold-attribute (mlir::Operation::getAttr op "value")))))

    ;; Same type in and out: folds to the operand.
    (define-op cast
      :operands ((x mlir::Value?))
      :results  ((out mlir::Value?))
      :traits   (pure)
      (:fold (op operand-attributes)
        (let ([x (mlir::Operation::getOperand op 0)])
          (and (equal? (mlir::Value::getType x)
                       (mlir::Value::getType (mlir::Operation::getResult op 0)))
               (list (fold-value x))))))

    ;; x + 0: folds to x when the second operand is the constant 0.
    (define-op add
      :operands ((lhs mlir::Value?) (rhs mlir::Value?))
      :results  ((out mlir::Value?))
      :traits   (pure)
      (:fold (op operand-attributes)
        (let ([rhs (cadr operand-attributes)])
          (and rhs
               (zero? (mlir::IntegerAttr::getValue rhs))
               (list (fold-value (mlir::Operation::getOperand op 0)))))))

    ;; No operands: folds to the attribute 7, which the dialect materializes as fd.const.
    (define-op seven
      :results ((out mlir::Value?))
      :traits  (pure)
      (:fold (op operand-attributes)
        (with-current-MLIRContext (mlir::Operation::getContext op)
          (list (fold-attribute (mlir::IntegerAttr::get<i64> 7))))))))

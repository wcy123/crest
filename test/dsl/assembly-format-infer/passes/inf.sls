#!r6rs
;; A dialect whose ops leave the result types out of their :assembly-format: they implement
;; InferTypeOpInterface and the parser asks it, as the ODS format of an op that can infer its types.
(library (passes inf)
  (export inf)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (mlir IR BuiltinTypes)
          (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface))

  (define-dialect inf
    ;; The result has the type of the left operand.
    (define-op add
      :operands   ((lhs mlir::Value?) (rhs mlir::Value?))
      :results    ((out mlir::Value?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (list (mlir::Value::getType (car operands))))))
      :assembly-format "$lhs `,` $rhs attr-dict `:` type($lhs) `,` type($rhs)")

    ;; No operands: nothing in the text says the type.
    (define-op zero
      :results    ((out mlir::Value?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (list (mlir::IntegerType::get<i64>)))))
      :assembly-format "attr-dict")

    ;; Two results, both of the operand's type.
    (define-op pair
      :operands   ((x mlir::Value?))
      :results    ((first mlir::Value?) (second mlir::Value?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (let ([type (mlir::Value::getType (car operands))])
                                        (list type type)))))
      :assembly-format "$x attr-dict `:` type($x)")))

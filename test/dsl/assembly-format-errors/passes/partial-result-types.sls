#!r6rs
;; The op implements InferTypeOpInterface, but the format names the type of one of its two results:
;; either every result type is in the format or none is.
(library (passes partial-result-types)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface))

  (define-dialect bad
    (define-op op
      :operands   ((input mlir::Value?))
      :results    ((first mlir::Value?) (second mlir::Value?))
      :interface2 ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (let ([type (mlir::Value::getType (car operands))])
                                        (list type type)))))
      :assembly-format "$input attr-dict `:` type($input) `->` type($first)")))

#!r6rs
;; An :interfaces entry of InferTypeOpInterface with a clause for a method that it does not have.
(library (passes unknown-infer-dialect)
  (export unkinf)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface))

  (define-dialect unkinf
    (define-op op
      :operands   ((x mlir::Value?))
      :results    ((out mlir::Value?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes) #f)
                    (inferResultTypes (context location operands attributes) #f))))))

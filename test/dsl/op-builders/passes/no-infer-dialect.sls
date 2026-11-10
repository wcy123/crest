#!r6rs
;; An :interfaces entry of InferTypeOpInterface without its inferReturnTypes clause.
(library (passes no-infer-dialect)
  (export noinf)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface))

  (define-dialect noinf
    (define-op op
      :operands   ((x mlir::Value?))
      :results    ((out mlir::Value?))
      :interfaces ((mlir::InferTypeOpInterface
                    (isCompatibleReturnTypes (inferred actual) #t))))))

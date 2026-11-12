#!r6rs
;; A dialect whose op fails to infer its result types: the clause answers #f.
(library (passes bad-dialect)
  (export bad)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface))

  (define-dialect bad
    (define-op op
      :operands   ((x mlir::Value?))
      :results    ((out mlir::Value?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      #f))))))

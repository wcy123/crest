#!r6rs
;; A dialect whose op raises an error when its result types are inferred.
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
      :interface2 ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (error 'infer "boom")))))))

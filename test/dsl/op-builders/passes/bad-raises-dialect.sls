#!r6rs
;; A dialect whose op raises an error when it infers its result types.
(library (passes bad-raises-dialect)
  (export badr)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface))

  (define-dialect badr
    (define-op op
      :operands   ((x mlir::Value?))
      :results    ((out mlir::Value?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (error 'inferReturnTypes "the clause is broken")))))))

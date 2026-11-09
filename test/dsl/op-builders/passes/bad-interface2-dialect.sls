#!r6rs
;; :interface2 takes a list of entries, not an interface name.
(library (passes bad-interface2-dialect)
  (export badi)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface))

  (define-dialect badi
    (define-op op
      :operands   ((x mlir::Value?))
      :results    ((out mlir::Value?))
      :interface2 mlir::InferTypeOpInterface)))

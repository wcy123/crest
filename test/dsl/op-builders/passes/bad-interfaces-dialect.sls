#!r6rs
;; :interfaces takes a list of entries, not an interface name.
(library (passes bad-interfaces-dialect)
  (export badi)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface))

  (define-dialect badi
    (define-op op
      :operands   ((x mlir::Value?))
      :results    ((out mlir::Value?))
      :interfaces mlir::InferTypeOpInterface)))

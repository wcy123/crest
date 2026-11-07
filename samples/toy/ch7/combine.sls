;; Toy Ch4 canonicalization patterns.
;; Mirrors mlir/examples/toy/Ch3/mlir/ToyCombine.cpp
;;         mlir/examples/toy/Ch3/mlir/ToyCombine.td
;;
;; Four patterns (same as Ch3 — Ch4 adds no new canonicalization patterns):
;;   SimplifyRedundantTranspose  — transpose(transpose(x)) → x
;;   ReshapeReshapeOpt           — reshape(reshape(x)) → reshape(x)
;;   RedundantReshape            — reshape(x) → x  when types are identical
;;   FoldConstantReshape         — reshape(constant(x)) → constant(x')
(library (toy ch7 combine)
  (export toy:add-canonicalization-patterns!)
  (import (except (rnrs) =)
          (only (mlir IR Value)
                mlir::Value::getDefiningOp
                mlir::Value::getType)
          (only (mlir IR Operation)
                mlir::Operation::getAttr
                mlir::Operation::getName)
          (only (mlir IR BuiltinAttributes)
                mlir::DenseElementsAttr::reshape
                mlir::DenseElementsAttr::getType
                mlir::ArrayAttr::getElement
                mlir::IntegerAttr::getValue)
          (crest))

  ;; SimplifyRedundantTranspose: transpose(transpose(x)) → x
  (define-rewrite-pattern (%%simplify-redundant-transpose op rewriter)
    :if-match
      %inner = toy.transpose (%in)
      %out   = toy.transpose (%inner)
    :rewrite %out :with
      %in)

  ;; ReshapeReshapeOpt: reshape(reshape(x)) → reshape(x)
  (define-rewrite-pattern (%%reshape-reshape op rewriter)
    :if-match
      %inner = toy.reshape (%in)
      %out   = toy.reshape (%inner)
    :then-let
      ([!out-type (mlir::Value::getType %out)])
    :rewrite %out :with
      result = toy.reshape (%in) -> !out-type)

  ;; RedundantReshape: reshape(x) → x when input and output types are identical
  (define-rewrite-pattern (%%redundant-reshape op rewriter)
    :if-match
      %out = toy.reshape (%in)
        :where
      (equal? (mlir::Value::getType %out) (mlir::Value::getType %in))
    :rewrite %out :with
      %in)

  ;; FoldConstantReshape: reshape(constant(x)) → constant(x')
  (define-rewrite-pattern (%%fold-constant-reshape op rewriter)
    :if-match
      %const = toy.constant ()
      %out   = toy.reshape (%const)
    :then-let
      ([!out-type (mlir::Value::getType %out)]
       [old-attr  (mlir::Operation::getAttr (mlir::Value::getDefiningOp %const) "value")]
       [new-attr  (mlir::DenseElementsAttr::reshape old-attr !out-type)])
    :rewrite %out :with
      result = toy.constant ()
      (value : new-attr)
      -> !out-type)

  ;; FoldStructAccessOfConstant: struct_access(struct_constant{[v0,v1,...]}, N) → constant{vN}
  (define-rewrite-pattern (%%fold-struct-access op rewriter)
    :if-match
      %struct = toy.struct_constant ()
      %field  = toy.struct_access (%struct)
    :then-let
      ([!arr      (mlir::Operation::getAttr (mlir::Value::getDefiningOp %struct) "value")]
       [!idx-attr (mlir::Operation::getAttr op "index")]
       [!idx      (mlir::IntegerAttr::getValue !idx-attr)]
       [!elem     (mlir::ArrayAttr::getElement !arr !idx)]
       [!type     (mlir::DenseElementsAttr::getType !elem)])
    :rewrite %field :with
      result = toy.constant ()
      (value : !elem)
      -> !type)

  ;; The patterns, as a set a pass can register with :populate.
  (define-pattern-set toy:add-canonicalization-patterns!
    ("toy.transpose" %%simplify-redundant-transpose 1)
    ("toy.reshape" %%reshape-reshape 1)
    ("toy.reshape" %%redundant-reshape 2)
    ("toy.reshape" %%fold-constant-reshape 1)
    ("toy.struct_access" %%fold-struct-access 1))

  ) ;; end library (toy ch7 combine)

;; Toy Ch3 canonicalization patterns.
;; Mirrors mlir/examples/toy/Ch3/mlir/ToyCombine.cpp
;;         mlir/examples/toy/Ch3/mlir/ToyCombine.td
;;
;; Three of four patterns implemented:
;;   SimplifyRedundantTranspose  — transpose(transpose(x)) → x
;;   ReshapeReshapeOpt           — reshape(reshape(x)) → reshape(x)
;;   RedundantReshape            — reshape(x) → x  when types are identical
;;
;; Four patterns from ToyCombine.cpp/td:
(library (toy ch3 combine)
  (export toy:add-canonicalization-patterns!)
  (import (except (rnrs) =)
          (only (mlir IR Value)
                mlir::Value::getDefiningOp
                mlir::Value::getType)
          (only (mlir IR Operation)
                mlir::Operation::getResult
                mlir::Operation::getName)
          (only (mlir IR BuiltinAttributes)
                mlir::DenseElementsAttr::reshape
                mlir::DenseElementsAttr::getType)
          (only (mlir IR Operation)
                mlir::Operation::getAttr)
          (only (mlir Transforms DialectConversion)
                add-rewrite-pattern)
          (crest))

  ;; SimplifyRedundantTranspose: transpose(transpose(x)) → x
  ;; Mirrors SimplifyRedundantTranspose in ToyCombine.cpp
  ;;
  ;; The :rewrite :with body returns %x — the original input to the inner
  ;; transpose — and the DSL calls replaceOp(op, %x) automatically.
  (define-rewrite-pattern (%%simplify-redundant-transpose op rewriter)
    :if-match
      %out = toy.transpose (%inner)
        :where
      (string=? (mlir::Operation::getName
                 (mlir::Value::getDefiningOp %inner))
                "toy.transpose")
    :then-let
      ([%x (mlir::Operation::getResult (mlir::Value::getDefiningOp %inner) 0)])
    :rewrite %out :with
      %x)

  ;; ReshapeReshapeOpt: reshape(reshape(x)) → reshape(x)
  ;; Mirrors ReshapeReshapeOptPattern in ToyCombine.td
  (define-rewrite-pattern (%%reshape-reshape op rewriter)
    :if-match
      %out = toy.reshape (%inner)
        :where
      (string=? (mlir::Operation::getName
                 (mlir::Value::getDefiningOp %inner))
                "toy.reshape")
    :then-let
      ([!out-type (mlir::Value::getType %out)]
       [%x        (mlir::Operation::getResult
                   (mlir::Value::getDefiningOp %inner) 0)])
    :rewrite %out :with
      result = toy.reshape (%x) -> !out-type)

  ;; RedundantReshape: reshape(x) → x when input and output types are identical
  ;; Mirrors RedundantReshapeOptPattern in ToyCombine.td
  (define-rewrite-pattern (%%redundant-reshape op rewriter)
    :if-match
      %out = toy.reshape (%in)
        :where
      (equal? (mlir::Value::getType %out) (mlir::Value::getType %in))
    :rewrite %out :with
      %in)

  ;; FoldConstantReshape: reshape(constant(x)) → constant(x')
  ;; Mirrors FoldConstantReshapeOptPattern in ToyCombine.td
  (define-rewrite-pattern (%%fold-constant-reshape op rewriter)
    :if-match
      %out = toy.reshape (%const)
        :where
      (string=? (mlir::Operation::getName
                 (mlir::Value::getDefiningOp %const))
                "toy.constant")
    :then-let
      ([!out-type  (mlir::Value::getType %out)]
       [const-op   (mlir::Value::getDefiningOp %const)]
       [old-attr   (mlir::Operation::getAttr const-op "value")]
       [new-attr   (mlir::DenseElementsAttr::reshape old-attr !out-type)])
    :rewrite %out :with
      result = toy.constant ()
      (value : new-attr)
      -> !out-type)

  ;; Register all four patterns into a RewritePatternSet.
  (define (toy:add-canonicalization-patterns! patterns)
    (add-rewrite-pattern patterns "toy.transpose" %%simplify-redundant-transpose 1)
    (add-rewrite-pattern patterns "toy.reshape"   %%reshape-reshape              1)
    (add-rewrite-pattern patterns "toy.reshape"   %%redundant-reshape            2)
    (add-rewrite-pattern patterns "toy.reshape"   %%fold-constant-reshape        1))

  ) ;; end library (toy ch3 combine)

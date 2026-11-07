;; Toy Ch5 shape inference.
;; Mirrors mlir/examples/toy/Ch5/mlir/ShapeInferencePass.cpp
;;
;; The front end emits tensor<*xf64> results. Each pattern below fires on an op with an unranked
;; result whose operands are ranked, and replaces it with the same op with the inferred result
;; type. The greedy rewriter applies them until nothing changes, which is the worklist of the C++
;; pass:
;;   toy.add, toy.mul   result type = type of the left operand
;;   toy.cast           result type = type of the input
;;   toy.transpose      result type = the input type with its shape reversed
(library (toy ch5 shape-inference)
  (export toy:add-shape-inference-patterns!
          toy:check-shapes-inferred!)
  (import (except (rnrs) =)
          (only (mlir IR Value)
                mlir::Value::getType)
          (only (mlir IR Operation)
                mlir::Operation::getLoc
                mlir::Operation::getName
                mlir::Operation::getNumResults
                mlir::Operation::getResult
                mlir::Operation::emitError
                mlir::Operation::walk)
          (only (mlir IR BuiltinTypes)
                mlir::RankedTensorType::get
                mlir::RankedTensorType::getShape
                mlir::RankedTensorType::getElementType
                mlir::isa<RankedTensorType>?)
          (crest))

  (define (%%ranked? value)
    (mlir::isa<RankedTensorType>? (mlir::Value::getType value)))

  (define-rewrite-pattern (%%infer-add op rewriter)
    :if-match
      %sum = toy.add (%lhs %rhs)
        :where (and (%%ranked? %lhs) (%%ranked? %rhs) (not (%%ranked? %sum)))
    :then-let
      ([!type (mlir::Value::getType %lhs)]
       [loc   (mlir::Operation::getLoc op)])
    :rewrite %sum :with
      result = toy.add (%lhs %rhs) :loc loc -> !type)

  (define-rewrite-pattern (%%infer-mul op rewriter)
    :if-match
      %product = toy.mul (%lhs %rhs)
        :where (and (%%ranked? %lhs) (%%ranked? %rhs) (not (%%ranked? %product)))
    :then-let
      ([!type (mlir::Value::getType %lhs)]
       [loc   (mlir::Operation::getLoc op)])
    :rewrite %product :with
      result = toy.mul (%lhs %rhs) :loc loc -> !type)

  (define-rewrite-pattern (%%infer-cast op rewriter)
    :if-match
      %out = toy.cast (%in)
        :where (and (%%ranked? %in) (not (%%ranked? %out)))
    :then-let
      ([!type (mlir::Value::getType %in)]
       [loc   (mlir::Operation::getLoc op)])
    :rewrite %out :with
      result = toy.cast (%in) :loc loc -> !type)

  (define-rewrite-pattern (%%infer-transpose op rewriter)
    :if-match
      %out = toy.transpose (%in)
        :where (and (%%ranked? %in) (not (%%ranked? %out)))
    :then-let
      ([input-type (mlir::Value::getType %in)]
       [!type      (mlir::RankedTensorType::get
                    (reverse (mlir::RankedTensorType::getShape input-type))
                    (mlir::RankedTensorType::getElementType input-type))]
       [loc        (mlir::Operation::getLoc op)])
    :rewrite %out :with
      result = toy.transpose (%in) :loc loc -> !type)

  ;; The patterns, as a set a pass can register with :populate.
  (define-pattern-set toy:add-shape-inference-patterns!
    ("toy.add" %%infer-add 1)
    ("toy.mul" %%infer-mul 1)
    ("toy.cast" %%infer-cast 1)
    ("toy.transpose" %%infer-transpose 1))

  ;; Report an error and exit if an op that shape inference handles still has an unranked result.
  (define (toy:check-shapes-inferred! module-op)
    (mlir::Operation::walk
     module-op
     (lambda (op)
       (when (and (> (mlir::Operation::getNumResults op) 0)
                  (not (%%ranked? (mlir::Operation::getResult op 0)))
                  (member (mlir::Operation::getName op)
                          '("toy.add" "toy.mul" "toy.cast" "toy.transpose")))
         (mlir::Operation::emitError
          op "shape inference failed: operand types not fully resolved")
         (exit 1)))))

  ) ;; end library (toy ch5 shape-inference)

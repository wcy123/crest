;; Toy Ch6 shape inference.
;; Mirrors mlir/examples/toy/Ch6/mlir/ShapeInferencePass.cpp
;;
;; The front end emits tensor<*xf64> results. Each pattern below fires on an op with an unranked
;; result whose operands are ranked, and replaces it with the same op with the inferred result
;; type. The greedy rewriter applies them until nothing changes, which is the worklist of the C++
;; pass:
;;   toy.add, toy.mul   result type = type of the left operand
;;   toy.cast           result type = type of the input
;;   toy.transpose      result type = the input type with its shape reversed
(library (toy ch6 shape-inference)
  (export toy:add-shape-inference-patterns!
          toy:shape-inference-pass)
  (import (except (rnrs) =)
          (only (mlir IR Value)
                mlir::Value::getType)
          (only (mlir IR Operation)
                mlir::Operation::getContext
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
          (only (mlir IR MLIRContext) with-current-MLIRContext)
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

  ;; ShapeInferencePass: infer the shapes of a function with the patterns above, then fail, as the
  ;; C++ pass does, when an operation's result is still not a ranked tensor.
  (define-pass (toy:shape-inference-pass func)
    (let ([ctx (mlir::Operation::getContext func)]
          [remaining 0])
      (with-current-MLIRContext ctx
        (apply-patterns func ctx :populate toy:add-shape-inference-patterns!))
      (mlir::Operation::walk
       func
       (lambda (op)
         (when (let loop ([i 0])
                 (and (< i (mlir::Operation::getNumResults op))
                      (or (not (%%ranked? (mlir::Operation::getResult op i)))
                          (loop (+ i 1)))))
           (set! remaining (+ remaining 1)))))
      (or (zero? remaining)
          (begin
            (mlir::Operation::emitError
             func (string-append "Shape inference failed, " (number->string remaining)
                                 " operations couldn't be inferred\n"))
            #f))))

  ) ;; end library (toy ch6 shape-inference)

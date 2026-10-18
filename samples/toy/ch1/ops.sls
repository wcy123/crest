;; Toy dialect op definitions
;; Mirrors mlir/examples/toy/Ch2/mlir/Dialect.cpp
(library (toy ch1 ops)
  (export
    toy.constant?  toy.constant:value  toy.constant:output  toy.constant:register!
    toy.print?     toy.print:input                          toy.print:register!
    toy.transpose? toy.transpose:input toy.transpose:output toy.transpose:register!
    toy.reshape?   toy.reshape:input   toy.reshape:output   toy.reshape:register!
    toy.mul?       toy.mul:lhs         toy.mul:rhs          toy.mul:register!
    toy.return?    toy.return:value                         toy.return:register!
    toy.func?                                               toy.func:register!
    toy-ops-initialize)
  (import (chezscheme)
          (crest op))

  (define-mlir-op toy.constant
    :summary    "Produce a constant tensor from a dense attribute"
    :attributes ((value  mlir::DenseElementsAttr))
    :results    ((output mlir::RankedTensorType)))

  (define-mlir-op toy.print
    :summary  "Print a tensor to stdout"
    :operands ((input mlir::Value)))

  (define-mlir-op toy.transpose
    :summary  "Transpose a 2D tensor"
    :operands ((input  mlir::Value))
    :results  ((output mlir::RankedTensorType)))

  (define-mlir-op toy.reshape
    :summary  "Reshape a tensor to a given type"
    :operands ((input  mlir::Value))
    :results  ((output mlir::RankedTensorType)))

  (define-mlir-op toy.mul
    :summary  "Element-wise multiplication of two tensors"
    :operands ((lhs mlir::Value)
               (rhs mlir::Value))
    :results  ((output mlir::RankedTensorType)))

  (define-mlir-op toy.return
    :summary  "Return from a toy.func"
    :operands ((value mlir::Value)))

  (define-mlir-op toy.func
    :summary  "A Toy function definition")

  ;; Called as the :initialize callback when loading the toy dialect.
  (define (toy-ops-initialize dialect-ptr)
    (toy.constant:register!  dialect-ptr)
    (toy.print:register!     dialect-ptr)
    (toy.transpose:register! dialect-ptr)
    (toy.reshape:register!   dialect-ptr)
    (toy.mul:register!       dialect-ptr)
    (toy.return:register!    dialect-ptr)
    (toy.func:register!      dialect-ptr)))

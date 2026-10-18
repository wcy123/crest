;; Toy dialect — all ops defined in one place
;; Mirrors mlir/examples/toy/Ch2/mlir/Dialect.cpp + Dialect.h
(library (toy ch1 toy)
  (export
    toy:register!
    toy.constant?  toy.constant:value  toy.constant:output
    toy.print?     toy.print:input
    toy.transpose? toy.transpose:input toy.transpose:output
    toy.reshape?   toy.reshape:input   toy.reshape:output
    toy.mul?       toy.mul:lhs         toy.mul:rhs         toy.mul:output
    toy.return?    toy.return:value
    toy.func?)
  (import (chezscheme)
          (crest dialect))

  (define-mlir-dialect toy
    (define-op constant
      :summary    "Produce a constant tensor from a dense attribute"
      :attributes ((value  mlir::DenseElementsAttr))
      :results    ((output mlir::RankedTensorType)))

    (define-op print
      :summary  "Print a tensor to stdout"
      :operands ((input mlir::Value)))

    (define-op transpose
      :summary  "Transpose a 2D tensor"
      :operands ((input  mlir::Value))
      :results  ((output mlir::RankedTensorType)))

    (define-op reshape
      :summary  "Reshape a tensor to a given type"
      :operands ((input  mlir::Value))
      :results  ((output mlir::RankedTensorType)))

    (define-op mul
      :summary  "Element-wise multiplication"
      :operands ((lhs mlir::Value)
                 (rhs mlir::Value))
      :results  ((output mlir::RankedTensorType)))

    (define-op return
      :summary  "Return from a toy.func"
      :operands ((value mlir::Value)))

    (define-op func
      :summary  "A Toy function definition")))

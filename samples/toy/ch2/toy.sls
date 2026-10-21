;; Toy dialect — all ops defined with define-dialect.
;; Mirrors mlir/examples/toy/Ch2/mlir/Dialect.cpp
;;         mlir/examples/toy/Ch2/include/toy/Dialect.h
;;         mlir/examples/toy/Ch2/include/toy/Ops.td
;;
;; In C++, ~400 lines of ODS + Dialect.cpp + generated code.
;; Here: define-dialect generates toy:register! and all accessors.
(library (toy ch2 toy)
  (export toy:register!)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Value)
          (mlir IR BuiltinTypes)
          (mlir IR BuiltinAttributes)
          (mlir IR Operation))

  (define-dialect toy
    ;; ConstantOp — tensor constant from a dense attribute
    (define-op constant
      :summary    "constant tensor"
      :attributes ((value mlir::DenseElementsAttr))
      :results    ((output mlir::RankedTensorType)))

    ;; AddOp — element-wise addition (f64 tensors)
    (define-op add
      :summary    "element-wise addition"
      :operands   ((lhs mlir::Value)
                   (rhs mlir::Value))
      :results    ((output mlir::RankedTensorType)))

    ;; MulOp — element-wise multiplication (f64 tensors)
    (define-op mul
      :summary    "element-wise multiplication"
      :operands   ((lhs mlir::Value)
                   (rhs mlir::Value))
      :results    ((output mlir::RankedTensorType)))

    ;; TransposeOp — transpose a 2D tensor
    (define-op transpose
      :summary    "transpose a 2D tensor"
      :operands   ((input mlir::Value))
      :results    ((output mlir::RankedTensorType)))

    ;; ReshapeOp — reshape a tensor to a given type
    (define-op reshape
      :summary    "reshape a tensor"
      :operands   ((input mlir::Value))
      :results    ((output mlir::RankedTensorType)))

    ;; GenericCallOp — call to a user-defined function
    (define-op generic_call
      :summary    "generic function call"
      :attributes ((callee mlir::StringAttr))
      :results    ((output mlir::RankedTensorType)))

    ;; FuncOp — toy function definition (body provided at codegen time)
    (define-op func
      :summary    "toy function definition")

    ;; ReturnOp — return from a toy function
    (define-op return
      :summary    "return from toy.func")

    ;; PrintOp — print a tensor to stdout
    (define-op print
      :summary    "print a tensor"
      :operands   ((input mlir::Value))))
  )

;; Toy dialect — all ops defined with define-dialect.
;; Mirrors mlir/examples/toy/Ch2/mlir/Dialect.cpp
;;         mlir/examples/toy/Ch2/include/toy/Dialect.h
;;         mlir/examples/toy/Ch2/include/toy/Ops.td
;;
;; In C++, ~400 lines of ODS + Dialect.cpp + generated code.
;; Here: define-dialect generates toy:register! and all accessors.
(library (toy ch2 toy)
  (export toy)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Value)
          (mlir IR BuiltinTypes)
          (mlir IR BuiltinAttributes)
          (mlir IR Operation)
          (mlir IR Types)
          (only (mlir IR OpImplementation)
                mlir::FunctionType::getNumResults
                mlir::FunctionType::getResult))

  ;; ---- The type constraints of the C++ Ops.td, and the verifiers of Dialect.cpp ----
  ;; (a verifier runs without an installed context, so types are compared by their properties)
  (define (%%f64? type)
    (and (mlir::isa<FloatType>? type) (eqv? 64 (mlir::FloatType::getWidth type))))

  ;; F64ElementsAttr: a dense attribute of f64 elements
  (define (%%f64-elements-attr? attr)
    (and (mlir::isa<DenseElementsAttr> attr)
         (%%f64? (mlir::TensorType::getElementType (mlir::DenseElementsAttr::getType attr)))))

  ;; FlatSymbolRefAttr
  (define (%%flat-symbol-ref-attr? attr) (mlir::isa<FlatSymbolRefAttr> attr))

  ;; F64Tensor: a ranked or unranked tensor of f64
  (define (%%f64-tensor? type)
    (and (mlir::isa<TensorType>? type)
         (%%f64? (mlir::TensorType::getElementType type))))

  ;; StaticShapeTensorOf<[F64]>
  (define (%%static-shape-f64-tensor? type)
    (and (mlir::isa<RankedTensorType>? type)
         (%%f64? (mlir::RankedTensorType::getElementType type))
         (for-all (lambda (dim) (>= dim 0)) (mlir::RankedTensorType::getShape type))))

  ;; AnyTypeOf<[F64Tensor, F64MemRef]>
  (define (%%f64-tensor-or-memref? type)
    (or (%%f64-tensor? type) (mlir::isa<MemRefType>? type)))

  (define (%%f64-tensor-value? value)
    (%%f64-tensor? (mlir::Value::getType value)))

  (define (%%f64-tensor-or-memref-value? value)
    (%%f64-tensor-or-memref? (mlir::Value::getType value)))

  (define (%%error op . parts)
    (mlir::Operation::emitError op (apply string-append parts))
    #f)

  ;; Variadic<...> operands: every operand satisfies the constraint (the DSL's :variadic needs an
  ;; operandSegmentSizes attribute, which C++ Toy's single variadic group does not have)
  (define (%%verify-operands op)
    (let loop ([i 0])
      (cond
       [(>= i (mlir::Operation::getNumOperands op)) #t]
       [(%%f64-tensor-value? (mlir::Operation::getOperand op i)) (loop (+ i 1))]
       [else (%%error op "operand #" (number->string i) " must be tensor of f64")])))

  ;; verifyConstantForType (a tensor constant; Ch7 adds the struct case)
  (define (%%verify-tensor-constant op type value)
    (cond
     [(not (and (mlir::isa<DenseElementsAttr> value)
                (mlir::isa<FloatType>?
                 (mlir::TensorType::getElementType (mlir::DenseElementsAttr::getType value)))))
      (%%error op "constant of TensorType must be initialized by a DenseFPElementsAttr")]
     [(not (mlir::isa<RankedTensorType>? type)) #t]
     [else
      (let ([attr-shape (mlir::RankedTensorType::getShape (mlir::DenseElementsAttr::getType value))]
            [shape      (mlir::RankedTensorType::getShape type)])
        (cond
         [(not (eqv? (length attr-shape) (length shape)))
          (%%error op "return type must match the one of the attached value attribute: "
                   (number->string (length attr-shape)) " != " (number->string (length shape)))]
         [else
          (let loop ([i 0] [a attr-shape] [s shape])
            (cond
             [(null? a) #t]
             [(eqv? (car a) (car s)) (loop (+ i 1) (cdr a) (cdr s))]
             [else
              (%%error op "return type shape mismatches its attribute at dimension "
                       (number->string i) ": " (number->string (car a)) " != "
                       (number->string (car s)))]))]))]))

  (define (%%verify-constant op)
    (%%verify-tensor-constant op (mlir::Value::getType (mlir::Operation::getResult op 0))
                              (mlir::Operation::getAttr op "value")))

  ;; ReturnOp::verify: at most one operand, matching the enclosing function's results
  (define (%%verify-return op)
    (let ([function (mlir::Operation::getParentOp op)])
      (cond
       [(not (%%verify-operands op)) #f]
       [(or (not function) (not (string=? (mlir::Operation::getName function) "toy.func"))) #t]
       [(> (mlir::Operation::getNumOperands op) 1)
        (%%error op "expects at most 1 return operand")]
       [else
        (let* ([results (mlir::FunctionType::getNumResults
                         (mlir::TypeAttr::getValue (mlir::Operation::getAttr function "function_type")))]
               [count   (mlir::Operation::getNumOperands op)])
          (cond
           [(not (eqv? count results))
            (%%error op "does not return the same number of values (" (number->string count)
                     ") as the enclosing function (" (number->string results) ")")]
           [(eqv? count 0) #t]
           [else
            (let ([input  (mlir::Value::getType (mlir::Operation::getOperand op 0))]
                  [result (mlir::FunctionType::getResult
                           (mlir::TypeAttr::getValue (mlir::Operation::getAttr function "function_type"))
                           0)])
              (or (equal? input result)
                  (mlir::isa<UnrankedTensorType>? input)
                  (mlir::isa<UnrankedTensorType>? result)
                  (%%error op "type of return operand (" (mlir::Type::print input)
                           ") doesn't match function result type (" (mlir::Type::print result) ")")))]))])))

  ;; TransposeOp::verify: the result shape is the input shape reversed
  (define (%%verify-transpose op)
    (let ([input  (mlir::Value::getType (mlir::Operation::getOperand op 0))]
          [result (mlir::Value::getType (mlir::Operation::getResult op 0))])
      (or (not (mlir::isa<RankedTensorType>? input))
          (not (mlir::isa<RankedTensorType>? result))
          (equal? (mlir::RankedTensorType::getShape input)
                  (reverse (mlir::RankedTensorType::getShape result)))
          (%%error op "expected result shape to be a transpose of the input"))))

  (define-dialect toy
    ;; ConstantOp — tensor constant from a dense attribute
    (define-op constant
      :summary    "constant tensor"
      :traits     (pure)
      :attributes ((value %%f64-elements-attr?))
      :results    ((output %%f64-tensor?))
      (:verify (op) (%%verify-constant op)))

    ;; AddOp — element-wise addition (f64 tensors)
    (define-op add
      :summary    "element-wise addition"
      :operands   ((lhs %%f64-tensor-value?)
                   (rhs %%f64-tensor-value?))
      :results    ((output %%f64-tensor?)))

    ;; MulOp — element-wise multiplication (f64 tensors)
    (define-op mul
      :summary    "element-wise multiplication"
      :operands   ((lhs %%f64-tensor-value?)
                   (rhs %%f64-tensor-value?))
      :results    ((output %%f64-tensor?)))

    ;; TransposeOp — transpose a 2D tensor
    (define-op transpose
      :summary    "transpose a 2D tensor"
      :operands   ((input %%f64-tensor-value?))
      :results    ((output %%f64-tensor?))
      (:verify (op) (%%verify-transpose op)))

    ;; ReshapeOp — reshape a tensor to a given type
    (define-op reshape
      :summary    "reshape a tensor"
      :operands   ((input %%f64-tensor-value?))
      :results    ((output %%static-shape-f64-tensor?)))

    ;; GenericCallOp — call to a user-defined function
    (define-op generic_call
      :summary    "generic function call"
      :attributes ((callee %%flat-symbol-ref-attr?))
      :results    ((output %%f64-tensor?))
      (:verify (op) (%%verify-operands op)))

    ;; FuncOp — toy function definition (body provided at codegen time)
    (define-op func
      :summary    "toy function definition"
      :traits     (isolated-from-above))

    ;; ReturnOp — return from a toy function
    (define-op return
      :summary    "return from toy.func"
      :traits     (terminator pure (has-parent "toy.func"))
      (:verify (op) (%%verify-return op)))

    ;; PrintOp — print a tensor to stdout
    (define-op print
      :summary    "print a tensor"
      :operands   ((input %%f64-tensor-value?))))
  )

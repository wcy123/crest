;; Toy dialect — all ops defined with define-dialect.
;; Mirrors mlir/examples/toy/Ch2/mlir/Dialect.cpp
;;         mlir/examples/toy/Ch2/include/toy/Dialect.h
;;         mlir/examples/toy/Ch2/include/toy/Ops.td
;;
;; In C++, ~400 lines of ODS + Dialect.cpp + generated code.
;; Here: define-dialect generates toy:register! and all accessors, and the text form of the ops that
;; C++ declares with an assemblyFormat is one :assembly-format string each.
(library (toy ch2 toy)
  (export toy)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Value)
          (mlir IR BuiltinTypes)
          (mlir IR BuiltinAttributes)
          (mlir IR Operation)
          (mlir IR Types)
          (mlir IR Block)
          (mlir IR Region)
          (mlir IR OpImplementation)
          (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface)
          (only (mlir Interfaces CallInterfaces) mlir::CallableOpInterface)
          (only (mlir Interfaces FunctionInterfaces)
                mlir::FunctionOpInterface
                mlir::function_interface_impl::printFunctionOp
                mlir::function_interface_impl::parseFunctionOp))

  ;; Handle-returning parser functions return 0 on failure (not #f),
  ;; so we need an explicit zero check rather than relying on Scheme truthiness.
  (define (%%parsed? h) (not (zero? h)))

  ;; InferTypeOpInterface, as the builders of the C++ Ops.td. AddOp, MulOp and TransposeOp make an
  ;; unranked f64 tensor (shape inference refines it later); ConstantOp has the type of its value.
  (define (%%unranked-f64-tensor-types)
    (list (mlir::UnrankedTensorType::get (mlir::Float64Type::get))))

  ;; isCompatibleReturnTypes of add, mul, transpose and constant: the inference of the first three is
  ;; tensor<*xf64> and shape inference refines the result to a ranked tensor; a constant that
  ;; materialization made may have an unranked result (its verifier checks a ranked one against the
  ;; value). So any f64 tensor fits.
  (define (%%f64-tensor-results? actual)
    (and (pair? actual) (null? (cdr actual)) (%%f64-tensor? (car actual))))

  (define (%%constant-result-types attributes)
    (let ([value (assoc "value" attributes)])
      (and value (list (mlir::DenseElementsAttr::getType (cdr value))))))

  ;; Shared parser for binary ops (add, mul).
  ;; Mirrors parseBinaryOp in Dialect.cpp.
  ;; Format: %lhs, %rhs {attrs} : type-or-func-type
  (define (%%parse-binary-op parser state)
    (let ([ops (mlir::OpAsmParser::parseOperandList parser 2)])
      (and (%%parsed? ops)
           (mlir::OpAsmParser::parseOptionalAttrDict parser state)
           (let ([type (mlir::OpAsmParser::parseColonType parser)])
             (and (%%parsed? type)
                  (if (mlir::isa<FunctionType> type)
                      ;; functional type: (t1, t2) -> t3
                      (and (mlir::OpAsmParser::resolveOperandsFunctional parser ops type state)
                           (begin (mlir::OperationState::addType state
                                                                 (mlir::FunctionType::getResult type 0))
                                  #t))
                      ;; same type for all operands and result
                      (and (mlir::OpAsmParser::resolveOperands parser ops type state)
                           (begin (mlir::OperationState::addType state type) #t))))))))

  ;; Shared printer for binary ops (add, mul).
  ;; Mirrors printBinaryOp in Dialect.cpp:
  ;;   if all types equal: print just that type
  ;;   otherwise: print functional type
  (define (%%print-binary-op op printer name)
    (mlir::OpAsmPrinter::printString printer " ")
    (mlir::OpAsmPrinter::printOperands printer op)
    (mlir::OpAsmPrinter::printOptionalAttrDict printer op)
    (mlir::OpAsmPrinter::printString printer " : ")
    (let ([result-type (mlir::Value::getType (mlir::Operation::getResult op 0))])
      (if (let loop ([i 0])
            (or (>= i (mlir::Operation::getNumOperands op))
                (and (= (mlir::Value::getType (mlir::Operation::getOperand op i))
                        result-type)
                     (loop (+ i 1)))))
          (mlir::OpAsmPrinter::printType printer result-type)
          (mlir::OpAsmPrinter::printFunctionalType printer op))))

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
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (%%constant-result-types attributes))
                    (isCompatibleReturnTypes (inferred actual)
                                             (%%f64-tensor-results? actual))))
      (:parse (parser state)
        (let ([attr (mlir::OpAsmParser::parseAttribute parser state "value")])
          (and (%%parsed? attr) (begin (mlir::OperationState::addType state
                                                                      (mlir::DenseElementsAttr::getType attr))
                                       #t))))
      (:print (op printer name)
        (mlir::OpAsmPrinter::printString printer " ")
        (mlir::OpAsmPrinter::printOptionalAttrDictExcept printer op "value")
        (mlir::OpAsmPrinter::printAttribute
         printer (mlir::Operation::getAttr op "value")))
      (:verify (op) (%%verify-constant op)))

    ;; AddOp — element-wise addition (f64 tensors)
    (define-op add
      :summary    "element-wise addition"
      :operands   ((lhs %%f64-tensor-value?)
                   (rhs %%f64-tensor-value?))
      :results    ((output %%f64-tensor?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (%%unranked-f64-tensor-types))
                    (isCompatibleReturnTypes (inferred actual)
                                             (%%f64-tensor-results? actual))))
      (:parse (parser state) (%%parse-binary-op parser state))
      (:print (op printer name) (%%print-binary-op op printer name)))

    ;; MulOp — element-wise multiplication (f64 tensors)
    (define-op mul
      :summary    "element-wise multiplication"
      :operands   ((lhs %%f64-tensor-value?)
                   (rhs %%f64-tensor-value?))
      :results    ((output %%f64-tensor?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (%%unranked-f64-tensor-types))
                    (isCompatibleReturnTypes (inferred actual)
                                             (%%f64-tensor-results? actual))))
      (:parse (parser state) (%%parse-binary-op parser state))
      (:print (op printer name) (%%print-binary-op op printer name)))

    ;; TransposeOp — transpose a 2D tensor
    (define-op transpose
      :summary    "transpose a 2D tensor"
      :operands   ((input %%f64-tensor-value?))
      :results    ((output %%f64-tensor?))
      :interfaces ((mlir::InferTypeOpInterface
                    (inferReturnTypes (context location operands attributes)
                                      (%%unranked-f64-tensor-types))
                    (isCompatibleReturnTypes (inferred actual)
                                             (%%f64-tensor-results? actual))))
      :assembly-format "`(` $input `:` type($input) `)` attr-dict `to` type(results)"
      (:verify (op) (%%verify-transpose op)))

    ;; ReshapeOp — reshape a tensor to a given type
    (define-op reshape
      :summary    "reshape a tensor"
      :operands   ((input %%f64-tensor-value?))
      :results    ((output %%static-shape-f64-tensor?))
      :assembly-format "`(` $input `:` type($input) `)` attr-dict `to` type(results)")

    ;; GenericCallOp — call to a user-defined function
    (define-op generic_call
      :summary    "generic function call"
      :attributes ((callee %%flat-symbol-ref-attr?))
      :results    ((output %%f64-tensor?))
      :operands   ((inputs %%f64-tensor-value? :variadic))
      :assembly-format "$callee `(` $inputs `)` attr-dict `:` functional-type($inputs, results)")

    ;; FuncOp — toy function definition (body provided at codegen time)
    (define-op func
      :summary    "toy function definition"
      :traits     (isolated-from-above)
      :interfaces ((mlir::CallableOpInterface
                    (getCallableRegion (self) (mlir::Operation::getRegion self 0))
                    (getArgumentTypes (self)
                                      (mlir::FunctionType::getInputs
                                       (mlir::TypeAttr::getValue
                                        (mlir::Operation::getAttr self "function_type"))))
                    (getResultTypes (self)
                                    (mlir::FunctionType::getResults
                                     (mlir::TypeAttr::getValue
                                      (mlir::Operation::getAttr self "function_type")))))
                   (mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (mlir::TypeAttr::getValue
                                      (mlir::Operation::getAttr self "function_type")))
                    (setFunctionTypeAttr (self attr)
                                         (mlir::Operation::setAttr! self "function_type" attr))))
      (:parse (parser state)
        (mlir::function_interface_impl::parseFunctionOp parser state))
      (:print (op printer name)
        (mlir::function_interface_impl::printFunctionOp printer op)))

    ;; ReturnOp — return from a toy function
    (define-op return
      :summary    "return from toy.func"
      :traits     (terminator pure (has-parent "toy.func"))
      :operands   ((input %%f64-tensor-value? :optional))
      :assembly-format "($input^ `:` type($input))? attr-dict "
      (:verify (op) (%%verify-return op)))

    ;; PrintOp — print a tensor to stdout
    (define-op print
      :summary    "print a tensor"
      :operands   ((input %%f64-tensor-value?))
      :assembly-format "$input attr-dict `:` type($input)"))
  )

;; Toy dialect — all ops defined with define-dialect.
;; Mirrors mlir/examples/toy/Ch3/mlir/Dialect.cpp
;;         mlir/examples/toy/Ch3/include/toy/Dialect.h
;;         mlir/examples/toy/Ch3/include/toy/Ops.td
;;
;; Ch3 adds no new ops vs Ch2, but adds custom assembly formats.
;; Canonicalization patterns live in combine.sls.
(library (toy ch3 toy)
  (export toy:register!)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Value)
          (mlir IR BuiltinTypes)
          (mlir IR BuiltinAttributes)
          (mlir IR Operation)
          (mlir IR Block)
          (mlir IR Region)
          (mlir IR OpImplementation)
          (only (mlir Interfaces FunctionInterfaces)
                crest::FunctionOpInterface::getConcept
                mlir::function_interface_impl::printFunctionOp))

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

  ;; Shared printer for single-input ops with explicit result type.
  ;; Format: (%input : input-type) to result-type
  ;; Mirrors TransposeOp/ReshapeOp assemblyFormat in Ops.td.
  (define (%%print-unary-to-type op printer name)
    (let ([input (mlir::Operation::getOperand op 0)])
      (mlir::OpAsmPrinter::printString printer "(")
      (mlir::OpAsmPrinter::printOperand printer input)
      (mlir::OpAsmPrinter::printString printer " : ")
      (mlir::OpAsmPrinter::printType printer (mlir::Value::getType input))
      (mlir::OpAsmPrinter::printString printer ")")
      (mlir::OpAsmPrinter::printOptionalAttrDict printer op)
      (mlir::OpAsmPrinter::printString printer " to ")
      (mlir::OpAsmPrinter::printResultTypes printer op)))

  (define-dialect toy
    ;; ConstantOp — tensor constant from a dense attribute.
    ;; Format: toy.constant {optional-attrs} value-attr
    ;; Mirrors ConstantOp::print in Dialect.cpp.
    (define-op constant
      :summary    "constant tensor"
      :attributes ((value mlir::DenseElementsAttr))
      :results    ((output mlir::RankedTensorType))
      (:print (op printer name)
              (mlir::OpAsmPrinter::printString printer " ")
              (mlir::OpAsmPrinter::printOptionalAttrDictExcept printer op "value")
              (mlir::OpAsmPrinter::printAttribute
               printer (mlir::Operation::getAttr op "value"))))

    ;; AddOp — element-wise addition (f64 tensors).
    ;; Format: toy.add %lhs, %rhs : type
    (define-op add
      :summary    "element-wise addition"
      :operands   ((lhs mlir::Value)
                   (rhs mlir::Value))
      :results    ((output mlir::RankedTensorType))
      (:print (op printer name) (%%print-binary-op op printer name)))

    ;; MulOp — element-wise multiplication (f64 tensors).
    ;; Format: toy.mul %lhs, %rhs : type
    (define-op mul
      :summary    "element-wise multiplication"
      :operands   ((lhs mlir::Value)
                   (rhs mlir::Value))
      :results    ((output mlir::RankedTensorType))
      (:print (op printer name) (%%print-binary-op op printer name)))

    ;; TransposeOp — transpose a 2D tensor.
    ;; Format: toy.transpose(%input : type) to result-type
    (define-op transpose
      :summary    "transpose a 2D tensor"
      :operands   ((input mlir::Value))
      :results    ((output mlir::RankedTensorType))
      (:print (op printer name) (%%print-unary-to-type op printer name)))

    ;; ReshapeOp — reshape a tensor to a given type.
    ;; Format: toy.reshape(%input : type) to result-type
    (define-op reshape
      :summary    "reshape a tensor"
      :operands   ((input mlir::Value))
      :results    ((output mlir::RankedTensorType))
      (:print (op printer name) (%%print-unary-to-type op printer name)))

    ;; GenericCallOp — call to a user-defined function.
    ;; Format: toy.generic_call @callee(%args) : functional-type
    (define-op generic_call
      :summary    "generic function call"
      :attributes ((callee mlir::StringAttr))
      :results    ((output mlir::RankedTensorType))
      (:print (op printer name)
              (mlir::OpAsmPrinter::printString printer " ")
              (mlir::OpAsmPrinter::printSymbolName
               printer
               (mlir::StringAttr::getValue (mlir::Operation::getAttr op "callee")))
              (mlir::OpAsmPrinter::printString printer "(")
              (mlir::OpAsmPrinter::printOperands printer op)
              (mlir::OpAsmPrinter::printString printer ")")
              (mlir::OpAsmPrinter::printOptionalAttrDictExcept printer op "callee")
              (mlir::OpAsmPrinter::printString printer " : ")
              (mlir::OpAsmPrinter::printFunctionalType printer op)))

    ;; FuncOp — toy function definition.
    ;; Format: toy.func @name(%arg0: type0, ...) -> (result_types) { body }
    ;; :interfaces wires FunctionOpInterface via the auto-generated
    ;; getRegisteredInterfaceForOp dialect hook.
    (define-op func
      :summary    "toy function definition"
      :interfaces (crest::FunctionOpInterface::getConcept)
      (:print (op printer name)
              (mlir::function_interface_impl::printFunctionOp printer op)))

    ;; ReturnOp — return from a toy function.
    ;; Format: toy.return (%val : type)?
    (define-op return
      :summary    "return from toy.func"
      (:print (op printer name)
              (when (> (mlir::Operation::getNumOperands op) 0)
                (let ([val (mlir::Operation::getOperand op 0)])
                  (mlir::OpAsmPrinter::printString printer " ")
                  (mlir::OpAsmPrinter::printOperand printer val)
                  (mlir::OpAsmPrinter::printString printer " : ")
                  (mlir::OpAsmPrinter::printType printer (mlir::Value::getType val))))))

    ;; PrintOp — print a tensor to stdout.
    ;; Format: toy.print %input : type
    (define-op print
      :summary    "print a tensor"
      :operands   ((input mlir::Value))
      (:print (op printer name)
              (let ([val (mlir::Operation::getOperand op 0)])
                (mlir::OpAsmPrinter::printString printer " ")
                (mlir::OpAsmPrinter::printOperand printer val)
                (mlir::OpAsmPrinter::printString printer " : ")
                (mlir::OpAsmPrinter::printType printer (mlir::Value::getType val)))))

    )
  )

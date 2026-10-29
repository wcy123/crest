;; Toy dialect — all ops defined with define-dialect.
;; Mirrors mlir/examples/toy/Ch3/mlir/Dialect.cpp
;;         mlir/examples/toy/Ch3/include/toy/Dialect.h
;;         mlir/examples/toy/Ch3/include/toy/Ops.td
;;
;; Ch3 adds no new ops vs Ch2, but adds custom assembly formats.
;; Canonicalization patterns live in combine.sls.
(library (toy ch3 toy)
  (export crest:get-toy-callbacks)
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
                mlir::FunctionOpInterface
                mlir::function_interface_impl::printFunctionOp
                mlir::function_interface_impl::parseFunctionOp)
          (only (mlir IR BuiltinAttributes)
                mlir::TypeAttr::getValue))

  ;; Handle-returning parser functions return 0 on failure (not #f),
  ;; so we need an explicit zero check rather than relying on Scheme truthiness.
  (define (%%parsed? h) (not (zero? h)))

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

  ;; Shared parser for single-input ops with explicit result type.
  ;; Format: (%input : input-type) attr-dict to result-type
  ;; Mirrors TransposeOp/ReshapeOp assemblyFormat.
  (define (%%parse-unary-to-type parser state)
    (and (mlir::OpAsmParser::parseLParen parser)
         (let ([ops (mlir::OpAsmParser::parseOperand parser)])
           (and (%%parsed? ops)
                (mlir::OpAsmParser::parseColon parser)
                (let ([in-type (mlir::OpAsmParser::parseType parser)])
                  (and (%%parsed? in-type)
                       (mlir::OpAsmParser::parseRParen parser)
                       (mlir::OpAsmParser::parseOptionalAttrDict parser state)
                       (mlir::OpAsmParser::parseKeyword parser "to")
                       (let ([res-type (mlir::OpAsmParser::parseType parser)])
                         (and (%%parsed? res-type)
                              (mlir::OpAsmParser::resolveOperands parser ops in-type state)
                              (begin (mlir::OperationState::addType state res-type) #t)))))))))

  ;; Parser for generic_call: @callee(%args) attr-dict : functional-type
  (define (%%parse-generic-call parser state)
    (and (string<? "" (mlir::OpAsmParser::parseSymbolName parser state))
         (mlir::OpAsmParser::parseLParen parser)
         (let ([ops (mlir::OpAsmParser::parseOperandList parser -1)])
           (and (%%parsed? ops)
                (mlir::OpAsmParser::parseRParen parser)
                (mlir::OpAsmParser::parseOptionalAttrDict parser state)
                (let ([ft (mlir::OpAsmParser::parseColonType parser)])
                  (and (%%parsed? ft)
                       (mlir::isa<FunctionType> ft)
                       (mlir::OpAsmParser::resolveOperandsFunctional parser ops ft state)
                       (let loop ([i 0] [n (mlir::FunctionType::getNumResults ft)])
                         (if (>= i n) #t
                             (begin (mlir::OperationState::addType
                                     state (mlir::FunctionType::getResult ft i))
                                    (loop (+ i 1) n))))))))))

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
    ;; Format: toy.constant {optional-attrs} dense<...>
    (define-op constant
      :summary    "constant tensor"
      :attributes ((value mlir::DenseElementsAttr))
      :results    ((output mlir::RankedTensorType))
      (:parse (parser state)
              (let ([attr (mlir::OpAsmParser::parseAttribute parser state "value")])
                (and (%%parsed? attr) (begin (mlir::OperationState::addType state
                                                                            (mlir::DenseElementsAttr::getType attr))
                                             #t))))
      (:print (op printer name)
              (mlir::OpAsmPrinter::printString printer " ")
              (mlir::OpAsmPrinter::printOptionalAttrDictExcept printer op "value")
              (mlir::OpAsmPrinter::printAttribute
               printer (mlir::Operation::getAttr op "value"))))

    ;; Format: toy.add %lhs, %rhs {attrs} : type
    (define-op add
      :summary    "element-wise addition"
      :operands   ((lhs mlir::Value)
                   (rhs mlir::Value))
      :results    ((output mlir::RankedTensorType))
      (:parse (parser state) (%%parse-binary-op parser state))
      (:print (op printer name) (%%print-binary-op op printer name)))

    ;; Format: toy.mul %lhs, %rhs {attrs} : type
    (define-op mul
      :summary    "element-wise multiplication"
      :operands   ((lhs mlir::Value)
                   (rhs mlir::Value))
      :results    ((output mlir::RankedTensorType))
      (:parse (parser state) (%%parse-binary-op parser state))
      (:print (op printer name) (%%print-binary-op op printer name)))

    ;; Format: toy.transpose(%input : type) to result-type
    (define-op transpose
      :summary    "transpose a 2D tensor"
      :operands   ((input mlir::Value))
      :results    ((output mlir::RankedTensorType))
      (:parse (parser state) (%%parse-unary-to-type parser state))
      (:print (op printer name) (%%print-unary-to-type op printer name)))

    ;; Format: toy.reshape(%input : type) to result-type
    (define-op reshape
      :summary    "reshape a tensor"
      :operands   ((input mlir::Value))
      :results    ((output mlir::RankedTensorType))
      (:parse (parser state) (%%parse-unary-to-type parser state))
      (:print (op printer name) (%%print-unary-to-type op printer name)))

    ;; Format: toy.generic_call @callee(%args) : functional-type
    (define-op generic_call
      :summary    "generic function call"
      :attributes ((callee mlir::StringAttr))
      :results    ((output mlir::RankedTensorType))
      (:parse (parser state)
              (%%parse-generic-call parser state))
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

    ;; Format: toy.func @name(%arg0: type, ...) { body }
    (define-op func
      :summary    "toy function definition"
      :interfaces ((mlir::FunctionOpInterface
                    (getFunctionType (self)
                                     (mlir::TypeAttr::getValue
                                      (mlir::Operation::getAttr self "function_type")))
                    (setFunctionTypeAttr (self attr)
                                         (mlir::Operation::setAttr! self "function_type" attr))))
      (:parse (parser state)
              (mlir::function_interface_impl::parseFunctionOp parser state))
      (:print (op printer name)
              (mlir::function_interface_impl::printFunctionOp printer op)))

    ;; Format: toy.return (%val : type)?
    (define-op return
      :summary    "return from toy.func"
      (:parse (parser state)
              ;; Optional return operand: parse silently, no error if absent.
              (let ([ops (mlir::OpAsmParser::parseOptionalOperand parser)])
                (if (%%parsed? ops)
                    (and (mlir::OpAsmParser::parseColon parser)
                         (let ([t (mlir::OpAsmParser::parseType parser)])
                           (and (%%parsed? t)
                                (mlir::OpAsmParser::resolveOperands
                                 parser ops t state))))
                    #t)))
      (:print (op printer name)
              (when (> (mlir::Operation::getNumOperands op) 0)
                (let ([val (mlir::Operation::getOperand op 0)])
                  (mlir::OpAsmPrinter::printString printer " ")
                  (mlir::OpAsmPrinter::printOperand printer val)
                  (mlir::OpAsmPrinter::printString printer " : ")
                  (mlir::OpAsmPrinter::printType printer (mlir::Value::getType val))))))

    ;; Format: toy.print %input : type
    (define-op print
      :summary    "print a tensor"
      :operands   ((input mlir::Value))
      (:parse (parser state)
              (let ([ops (mlir::OpAsmParser::parseOperand parser)])
                (and (%%parsed? ops)
                     (mlir::OpAsmParser::parseColon parser)
                     (let ([t (mlir::OpAsmParser::parseType parser)])
                       (and (%%parsed? t)
                            (mlir::OpAsmParser::resolveOperands
                             parser ops t state))))))
      (:print (op printer name)
              (let ([val (mlir::Operation::getOperand op 0)])
                (mlir::OpAsmPrinter::printString printer " ")
                (mlir::OpAsmPrinter::printOperand printer val)
                (mlir::OpAsmPrinter::printString printer " : ")
                (mlir::OpAsmPrinter::printType printer (mlir::Value::getType val)))))

    )
  )

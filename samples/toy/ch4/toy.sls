;; Toy dialect for Ch4.
;; Mirrors mlir/examples/toy/Ch4/mlir/Dialect.cpp
;;
;; Ch4 adds:
;;   - toy.cast op (bridges ranked/unranked type mismatches at call boundaries)
;;   - DialectInlinerInterface so MLIR's inliner can inline toy.generic_call
(library (toy ch4 toy)
  (export toy)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Value)
          (mlir IR BuiltinTypes)
          (mlir IR BuiltinAttributes)
          (mlir IR Operation)
          (mlir IR Block)
          (mlir IR Region)
          (mlir IR OpImplementation)
          (mlir IR Builders)
          (mlir IR OperationSupport)
          (only (mlir Interfaces FunctionInterfaces)
                mlir::FunctionOpInterface
                mlir::function_interface_impl::printFunctionOp
                mlir::function_interface_impl::parseFunctionOp))

  (define %%add-inliner-interface!
    (foreign-procedure "crest::add-inliner-interface!"
                       (uptr scheme-object scheme-object) void))

  (define (%%parsed? h) (not (zero? h)))

  (define (%%parse-binary-op parser state)
    (let ([ops (mlir::OpAsmParser::parseOperandList parser 2)])
      (and (%%parsed? ops)
           (mlir::OpAsmParser::parseOptionalAttrDict parser state)
           (let ([type (mlir::OpAsmParser::parseColonType parser)])
             (and (%%parsed? type)
                  (if (mlir::isa<FunctionType> type)
                      (and (mlir::OpAsmParser::resolveOperandsFunctional parser ops type state)
                           (begin (mlir::OperationState::addType state
                                                                 (mlir::FunctionType::getResult type 0))
                                  #t))
                      (and (mlir::OpAsmParser::resolveOperands parser ops type state)
                           (begin (mlir::OperationState::addType state type) #t))))))))

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

  ;; -------------------------------------------------------------------------
  ;; Inliner interface callbacks
  ;; -------------------------------------------------------------------------

  ;; toy.return terminator: replace each valuesToRepl[i] with return operand[i].
  (define (%%toy-handle-terminator op n-replacements replacements)
    (let loop ([i 0] [repls replacements])
      (when (< i n-replacements)
        (let ([return-operand (mlir::Operation::getOperand op i)]
              [replacement    (car repls)])
          (mlir::Value::replaceAllUsesWith replacement return-operand))
        (loop (+ i 1) (cdr repls)))))

  ;; Insert a toy.cast to bridge type mismatch at call boundaries.
  ;; Returns the Operation* (not the Value) as expected by materializeCallConversion.
  (define (%%toy-materialize-call-conversion builder input result-type loc)
    (with-OperationState (s loc "toy.cast")
                         (mlir::OperationState::addOperands s input)
                         (mlir::OperationState::addTypes s result-type)
                         (mlir::OpBuilder::create<OperationState> builder s)))

  (define-dialect toy
    (define-op constant
      :summary    "constant tensor"
      :attributes ((value mlir::DenseElementsAttr))
      :results    ((output mlir::isa<RankedTensorType>?))
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

    ;; add/mul/transpose/reshape/cast: result type is mlir::Value (any tensor)
    ;; because mlir-gen produces unranked results that shape inference resolves.
    (define-op add
      :summary    "element-wise addition"
      :operands   ((lhs mlir::Value)
                   (rhs mlir::Value))
      :results    ((output mlir::isa<RankedTensorType>?))
      (:parse (parser state) (%%parse-binary-op parser state))
      (:print (op printer name) (%%print-binary-op op printer name)))

    (define-op mul
      :summary    "element-wise multiplication"
      :operands   ((lhs mlir::Value)
                   (rhs mlir::Value))
      :results    ((output mlir::isa<RankedTensorType>?))
      (:parse (parser state) (%%parse-binary-op parser state))
      (:print (op printer name) (%%print-binary-op op printer name)))

    (define-op transpose
      :summary    "transpose a 2D tensor"
      :operands   ((input mlir::Value))
      :results    ((output mlir::isa<RankedTensorType>?))
      (:parse (parser state) (%%parse-unary-to-type parser state))
      (:print (op printer name) (%%print-unary-to-type op printer name)))

    (define-op reshape
      :summary    "reshape a tensor"
      :operands   ((input mlir::Value))
      :results    ((output mlir::isa<RankedTensorType>?))
      (:parse (parser state) (%%parse-unary-to-type parser state))
      (:print (op printer name) (%%print-unary-to-type op printer name)))

    ;; toy.cast — bridge ranked/unranked mismatch at call boundaries.
    ;; Inserted by the inliner's materializeCallConversion.
    ;; Result type is mlir::Value (any tensor) since the cast can produce
    ;; either ranked or unranked tensors depending on call direction.
    (define-op cast
      :summary    "cast tensor to a different shape"
      :operands   ((input mlir::Value))
      :results    ((output mlir::isa<RankedTensorType>?))
      (:parse (parser state) (%%parse-unary-to-type parser state))
      (:print (op printer name) (%%print-unary-to-type op printer name)))

    (define-op generic_call
      :summary    "generic function call"
      :attributes ((callee mlir::StringAttr))
      :results    ((output mlir::isa<RankedTensorType>?))
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

    (define-op return
      :summary    "return from toy.func"
      (:parse (parser state)
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
                (mlir::OpAsmPrinter::printType printer (mlir::Value::getType val))))))

  ;; Register the inliner interface after define-dialect has generated
  ;; the callbacks vector. The vector is mutable so we wrap slot 0.
  (let ([%%original-init (vector-ref toy 0)])
    (vector-set! toy 0
                 (lambda (dialect-ptr)
                   (%%original-init dialect-ptr)
                   (%%add-inliner-interface!
                    dialect-ptr
                    %%toy-handle-terminator
                    %%toy-materialize-call-conversion))))

  ) ;; end library (toy ch4 toy)

;; Toy dialect for Ch4.
;; Mirrors mlir/examples/toy/Ch4/mlir/Dialect.cpp
;;
;; Ch4 adds:
;;   - toy.cast op (bridges ranked/unranked type mismatches at call boundaries)
;;   - DialectInlinerInterface, the interface MLIR's inliner would use for toy.generic_call.
;;     toyc.sls inlines in Scheme instead: MLIR's inliner needs the call interfaces and a
;;     terminator trait, which a Scheme dialect cannot declare before LLVM 23.
(library (toy ch6 toy)
  (export toy)
  (import (except (chezscheme) =)
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
                mlir::function_interface_impl::parseFunctionOp)
          (only (mlir support array-ref) crest::CArrayRef::size crest::CArrayRef::at)
          (for (except (rime loop) :name) expand)
          (for (only (crest pattern-dsl rewrite) begin-mlir-code) expand)
          (for (only (crest pattern-dsl keywords) = :string :loc :arg) expand)
          (only (crest pattern-dsl keywords) = : -> :region :loc
                :string :index :i8 :i16 :i32 :i64 :f32 :f64
                :i8-array :i16-array :i32-array :i64-array :unit))

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
    (and (string<? "" (mlir::OpAsmParser::parseSymbolName parser state "callee"))
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
                (and (eqv? (mlir::Value::getType (mlir::Operation::getOperand op i))
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

  (define-dialect toy
    (:interfaces ((mlir::DialectInlinerInterface
                   (isLegalToInline/call   (call callable wouldBeCloned) #t)
                   (isLegalToInline/region (dest src wouldBeCloned) #t)
                   (isLegalToInline/op     (op dest wouldBeCloned) #t)
                   (handleTerminator/value (op replacements)
                                           (loop :for i :from 0 :below (crest::CArrayRef::size replacements)
                                                 :do (mlir::Value::replaceAllUsesWith
                                                      (crest::CArrayRef::at replacements i)
                                                      (mlir::Operation::getOperand op i))))
                   (handleTerminator/block (op new-dest) #f)
                   (materializeCallConversion (builder input result-type loc)
                     ;; MLIR wants the op, not its result.
                     (with-current-OpBuilder builder
                       (mlir::Value::getDefiningOp
                        (begin-mlir-code
                            r = toy.cast (input) :loc loc -> result-type)))))))
    (define-op constant
      :summary    "constant tensor"
      :attributes ((value mlir::DenseElementsAttr))
      :results    ((output mlir::Value?))
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
      :operands   ((lhs mlir::Value?)
                   (rhs mlir::Value?))
      :results    ((output mlir::Value?))
      (:parse (parser state) (%%parse-binary-op parser state))
      (:print (op printer name) (%%print-binary-op op printer name)))

    (define-op mul
      :summary    "element-wise multiplication"
      :operands   ((lhs mlir::Value?)
                   (rhs mlir::Value?))
      :results    ((output mlir::Value?))
      (:parse (parser state) (%%parse-binary-op parser state))
      (:print (op printer name) (%%print-binary-op op printer name)))

    (define-op transpose
      :summary    "transpose a 2D tensor"
      :operands   ((input mlir::Value?))
      :results    ((output mlir::Value?))
      (:parse (parser state) (%%parse-unary-to-type parser state))
      (:print (op printer name) (%%print-unary-to-type op printer name)))

    (define-op reshape
      :summary    "reshape a tensor"
      :operands   ((input mlir::Value?))
      :results    ((output mlir::Value?))
      (:parse (parser state) (%%parse-unary-to-type parser state))
      (:print (op printer name) (%%print-unary-to-type op printer name)))

    ;; toy.cast — bridge ranked/unranked mismatch at call boundaries.
    ;; Inserted by the inliner's materializeCallConversion.
    ;; Result is mlir::Value? (any value) — cast can produce ranked or unranked.
    (define-op cast
      :summary    "cast tensor to a different shape"
      :operands   ((input mlir::Value?))
      :results    ((output mlir::Value?))
      (:parse (parser state) (%%parse-unary-to-type parser state))
      (:print (op printer name) (%%print-unary-to-type op printer name)))

    (define-op generic_call
      :summary    "generic function call"
      :attributes ((callee mlir::StringAttr))
      :results    ((output mlir::Value?))
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
      :operands   ((input mlir::Value?))
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

  ) ;; end library (toy ch6 toy)

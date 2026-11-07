;; Toy dialect for Ch4.
;; Mirrors mlir/examples/toy/Ch4/mlir/Dialect.cpp
;;
;; Ch4 adds:
;;   - toy.cast op (bridges ranked/unranked type mismatches at call boundaries)
;;   - DialectInlinerInterface, the interface MLIR's inliner uses for toy.generic_call, and what the
;;     pass needs from the ops: CallOpInterface on toy.generic_call, FunctionOpInterface on toy.func
;;     (so it is callable), and `:traits (terminator)` on toy.return (LLVM 23).
(library (toy ch7 toy)
  (export toy)
  (import (except (chezscheme) =)
          (crest dialect)
          (mlir IR Value)
          (mlir IR BuiltinTypes)
          (mlir IR BuiltinAttributes)
          (mlir IR Operation)
          (mlir IR Types)
          (mlir IR Block)
          (mlir IR Region)
          (mlir IR OpImplementation)
          (mlir IR Builders)
          (mlir IR OperationSupport)
          (only (mlir Interfaces CallInterfaces) mlir::CallOpInterface)
          (only (mlir Interfaces FunctionInterfaces)
                mlir::FunctionOpInterface
                mlir::function_interface_impl::printFunctionOp
                mlir::function_interface_impl::parseFunctionOp)
          (only (mlir support array-ref) crest::CArrayRef::size crest::CArrayRef::at)
          (only (mlir IR OpImplementation) mlir::OpAsmParser::parseOptionalComma
                mlir::OpAsmParser::parseLess
                mlir::OpAsmParser::parseGreater
                mlir::OpAsmParser::parseLSquare
                mlir::OpAsmParser::parseRSquare)
          (mlir Dialect Toy ToyStructType)
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
    (and (%%parsed? (mlir::OpAsmParser::parseAttribute parser state "callee"))
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

  ;; ===--- Ch7: struct type parse/print helpers ---===

  (define (%%parse-type-list parser)
    ;; Parse comma-separated types until '>'
    (let loop ([types '()])
      (let ([t (mlir::OpAsmParser::parseType parser)])
        (if (zero? t)
            #f
            (let ([types (append types (list t))])
              (if (zero? (mlir::OpAsmParser::parseOptionalComma parser))
                  types
                  (loop types)))))))

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
       [(%%toy-type-value? (mlir::Operation::getOperand op i)) (loop (+ i 1))]
       [else (%%error op "operand #" (number->string i) " must be tensor of f64 or Toy struct")])))

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

  (define (%%verify-constant-for-type op type value)
    (cond
     [(mlir::isa<TensorType>? type) (%%verify-tensor-constant op type value)]
     [else
      (let ([elements (toy::StructType::getElementTypes type)])
        (if (and (mlir::isa<ArrayAttr> value)
                 (eqv? (mlir::ArrayAttr::size value) (length elements)))
            (let loop ([i 0] [types elements])
              (cond
               [(null? types) #t]
               [(%%verify-constant-for-type op (car types) (mlir::ArrayAttr::getElement value i))
                (loop (+ i 1) (cdr types))]
               [else #f]))
            (%%error op "constant of StructType must be initialized by an ArrayAttr with the "
                     "same number of elements")))]))

  (define (%%verify-constant op)
    (%%verify-constant-for-type op (mlir::Value::getType (mlir::Operation::getResult op 0))
                                (mlir::Operation::getAttr op "value")))

  ;; StructAccessOp::verify
  (define (%%verify-struct-access op)
    (let* ([struct-type (mlir::Value::getType (mlir::Operation::getOperand op 0))]
           [index       (mlir::IntegerAttr::getValue (mlir::Operation::getAttr op "index"))]
           [elements    (toy::StructType::getElementTypes struct-type)])
      (cond
       [(>= index (length elements))
        (%%error op "index should be within the range of the input struct type")]
       [(not (equal? (mlir::Value::getType (mlir::Operation::getResult op 0))
                     (list-ref elements index)))
        (%%error op "must have the same result type as the struct element referred to by "
                 "the index")]
       [else #t])))

  (define (%%struct-type-value? value)
    (toy::StructType? (mlir::Value::getType value)))

  (define (%%integer-attr? attr) (mlir::isa<IntegerAttr> attr))
  (define (%%array-attr? attr) (mlir::isa<ArrayAttr> attr))

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

  ;; Toy_StructType and Toy_Type = AnyTypeOf<[F64Tensor, Toy_StructType]>
  (define (%%toy-type? type)
    (or (%%f64-tensor? type) (toy::StructType? type)))

  (define (%%toy-type-value? value)
    (%%toy-type? (mlir::Value::getType value)))

  (define-dialect toy
    (:parse-type (parser)
      ;; parse `struct` `<` type-list `>`
      (and (not (zero? (mlir::OpAsmParser::parseKeyword parser "struct")))
           (not (zero? (mlir::OpAsmParser::parseLess parser)))
           (let ([types (%%parse-type-list parser)])
             (and types
                  (not (zero? (mlir::OpAsmParser::parseGreater parser)))
                  (toy::StructType::get types)))))
    (:print-type (type printer)
      (when (toy::StructType? type)
        (mlir::OpAsmPrinter::printString printer "struct<")
        (let ([elems (toy::StructType::getElementTypes type)])
          (let loop ([ts elems] [first #t])
            (unless (null? ts)
              (unless first (mlir::OpAsmPrinter::printString printer ", "))
              (mlir::OpAsmPrinter::printType printer (car ts))
              (loop (cdr ts) #f))))
        (mlir::OpAsmPrinter::printString printer ">")))
    ;; Must return the op, not its result: MLIR casts the value to an Operation*.
    (:materialize-constant (builder value type loc)
      (with-current-OpBuilder builder
        (mlir::Value::getDefiningOp
         (if (toy::StructType? type)
             (begin-mlir-code
                 r = toy.struct_constant () (value : value) :loc loc -> type)
             (begin-mlir-code
                 r = toy.constant () (value : value) :loc loc -> type)))))
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
      :traits     (constant-like pure)
      :attributes ((value %%f64-elements-attr?))
      :results    ((output %%f64-tensor?))
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
      ;; ConstantOp::fold: a constant folds to its value.
      (:fold (op operand-attributes)
        (list (fold-attribute (mlir::Operation::getAttr op "value"))))
      (:verify (op) (%%verify-constant op)))

    ;; add/mul/transpose/reshape/cast: result type is mlir::Value (any tensor)
    ;; because mlir-gen produces unranked results that shape inference resolves.
    (define-op add
      :summary    "element-wise addition"
      :operands   ((lhs %%f64-tensor-value?)
                   (rhs %%f64-tensor-value?))
      :results    ((output %%f64-tensor?))
      (:parse (parser state) (%%parse-binary-op parser state))
      (:print (op printer name) (%%print-binary-op op printer name)))

    (define-op mul
      :summary    "element-wise multiplication"
      :operands   ((lhs %%f64-tensor-value?)
                   (rhs %%f64-tensor-value?))
      :results    ((output %%f64-tensor?))
      (:parse (parser state) (%%parse-binary-op parser state))
      (:print (op printer name) (%%print-binary-op op printer name)))

    (define-op transpose
      :summary    "transpose a 2D tensor"
      :operands   ((input %%f64-tensor-value?))
      :results    ((output %%f64-tensor?))
      (:parse (parser state) (%%parse-unary-to-type parser state))
      (:print (op printer name) (%%print-unary-to-type op printer name))
      (:verify (op) (%%verify-transpose op)))

    (define-op reshape
      :summary    "reshape a tensor"
      :operands   ((input %%f64-tensor-value?))
      :results    ((output %%static-shape-f64-tensor?))
      (:parse (parser state) (%%parse-unary-to-type parser state))
      (:print (op printer name) (%%print-unary-to-type op printer name)))

    ;; toy.cast — bridge ranked/unranked mismatch at call boundaries.
    ;; Inserted by the inliner's materializeCallConversion.
    ;; Result is mlir::Value? (any value) — cast can produce ranked or unranked.
    (define-op cast
      :summary    "cast tensor to a different shape"
      :traits     (same-operands-and-result-shape)
      :operands   ((input %%f64-tensor-value?))
      :results    ((output %%f64-tensor?))
      (:parse (parser state) (%%parse-unary-to-type parser state))
      (:print (op printer name) (%%print-unary-to-type op printer name))
      ;; What CastOpInterface's folder does in C++: a cast to the type it already has is its operand.
      (:fold (op operand-attributes)
        (let ([in (mlir::Operation::getOperand op 0)])
          (and (equal? (mlir::Value::getType in)
                       (mlir::Value::getType (mlir::Operation::getResult op 0)))
               (list (fold-value in))))))

    (define-op generic_call
      :summary    "generic function call"
      :interfaces ((mlir::CallOpInterface))
      :attributes ((callee %%flat-symbol-ref-attr?))
      :results    ((output %%toy-type?))
      (:parse (parser state)
        (%%parse-generic-call parser state))
      (:print (op printer name)
        (mlir::OpAsmPrinter::printString printer " ")
        (mlir::OpAsmPrinter::printSymbolName
         printer
         (mlir::FlatSymbolRefAttr::getValue (mlir::Operation::getAttr op "callee")))
        (mlir::OpAsmPrinter::printString printer "(")
        (mlir::OpAsmPrinter::printOperands printer op)
        (mlir::OpAsmPrinter::printString printer ")")
        (mlir::OpAsmPrinter::printOptionalAttrDictExcept printer op "callee")
        (mlir::OpAsmPrinter::printString printer " : ")
        (mlir::OpAsmPrinter::printFunctionalType printer op))
      (:verify (op) (%%verify-operands op)))

    (define-op func
      :summary    "toy function definition"
      :traits     (isolated-from-above)
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
      :traits     (terminator (has-parent "toy.func"))
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
            (mlir::OpAsmPrinter::printType printer (mlir::Value::getType val)))))
      (:verify (op) (%%verify-return op)))

    (define-op print
      :summary    "print a tensor"
      :operands   ((input %%f64-tensor-or-memref-value?))
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

    ;; Ch7: toy.struct_constant [attr-list] : !toy.struct<...>
    (define-op struct_constant
      :summary    "struct constant value"
      :traits     (constant-like pure)
      :attributes ((value %%array-attr?))
      :results    ((output toy::StructType?))
      (:verify (op) (%%verify-constant op))
      (:parse (parser state)
        ;; parse ArrayAttr then ':' StructType
        (let ([attr (mlir::OpAsmParser::parseAttribute parser state "value")])
          (and (%%parsed? attr)
               (mlir::OpAsmParser::parseColon parser)
               (let ([t (mlir::OpAsmParser::parseType parser)])
                 (and (%%parsed? t)
                      (begin (mlir::OperationState::addType state t) #t))))))
      (:print (op printer name)
        (mlir::OpAsmPrinter::printString printer " ")
        (mlir::OpAsmPrinter::printAttribute printer
                                            (mlir::Operation::getAttr op "value"))
        (mlir::OpAsmPrinter::printString printer " : ")
        (mlir::OpAsmPrinter::printType printer
                                       (mlir::Value::getType
                                        (mlir::Operation::getResult op 0))))
      ;; StructConstantOp::fold: a struct constant folds to its value.
      (:fold (op operand-attributes)
        (list (fold-attribute (mlir::Operation::getAttr op "value")))))

    ;; Ch7: toy.struct_access %val[N] : !toy.struct<...> -> resultType
    (define-op struct_access
      :summary    "struct field access"
      :traits     (pure)
      :operands   ((input %%struct-type-value?))
      :attributes ((index %%integer-attr?))
      :results    ((output %%toy-type?))
      (:verify (op) (%%verify-struct-access op))
      (:parse (parser state)
        (let ([ops (mlir::OpAsmParser::parseOperand parser)])
          (and (%%parsed? ops)
               (mlir::OpAsmParser::parseLSquare parser)
               (let ([idx-attr (mlir::OpAsmParser::parseAttribute parser state "index")])
                 (and (%%parsed? idx-attr)
                      (mlir::OpAsmParser::parseRSquare parser)
                      (mlir::OpAsmParser::parseColon parser)
                      (let ([input-t (mlir::OpAsmParser::parseType parser)])
                        (and (%%parsed? input-t)
                             (mlir::OpAsmParser::parseArrow parser)
                             (let ([result-t (mlir::OpAsmParser::parseType parser)])
                               (and (%%parsed? result-t)
                                    (mlir::OpAsmParser::resolveOperands
                                     parser ops input-t state)
                                    (begin (mlir::OperationState::addType state result-t)
                                           #t))))))))))
      (:print (op printer name)
        (let ([input (mlir::Operation::getOperand op 0)]
              [idx   (mlir::Operation::getAttr op "index")])
          (mlir::OpAsmPrinter::printString printer " ")
          (mlir::OpAsmPrinter::printOperand printer input)
          (mlir::OpAsmPrinter::printString printer "[")
          (mlir::OpAsmPrinter::printAttribute printer idx)
          (mlir::OpAsmPrinter::printString printer "]")
          (mlir::OpAsmPrinter::printOptionalAttrDictExcept printer op "index")
          (mlir::OpAsmPrinter::printString printer " : ")
          (mlir::OpAsmPrinter::printType printer (mlir::Value::getType input))
          (mlir::OpAsmPrinter::printString printer " -> ")
          (mlir::OpAsmPrinter::printType printer
                                         (mlir::Value::getType
                                          (mlir::Operation::getResult op 0)))))
      ;; StructAccessOp::fold: an access to a constant struct is the element.
      (:fold (op operand-attributes)
        (let ([in (car operand-attributes)])
          (and in
               (list (fold-attribute
                      (mlir::ArrayAttr::getElement
                       in (mlir::IntegerAttr::getValue
                           (mlir::Operation::getAttr op "index")))))))))

    ) ;; end define-dialect toy

  ) ;; end library (toy ch7 toy)

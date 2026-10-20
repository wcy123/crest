;; MLIR code generation from the Toy AST.
;; Mirrors mlir/examples/toy/Ch2/mlir/MLIRGen.cpp
;;         mlir/examples/toy/Ch2/include/toy/MLIRGen.h
(library (toy ch2 mlir-gen)
  (export mlir-gen)
  (import (chezscheme)
          (mlir IR MLIRContext)
          (mlir IR Builders)
          (mlir IR BuiltinTypes)
          (mlir IR BuiltinAttributes)
          (mlir IR Location)
          (mlir IR OperationSupport)
          (mlir IR Operation)
          (mlir IR Region)
          (mlir IR Block)
          (toy ch1 ast))

  ;; -------------------------------------------------------------------------
  ;; Helpers
  ;; -------------------------------------------------------------------------

  ;; loc — mirrors MLIRGenImpl::loc()
  ;; Convert a Toy AST location to an mlir::Location.
  (define (%%loc toy-loc)
    (mlir::FileLineColLoc::get
     (current-MLIRContext)
     (location:file toy-loc)
     (location:line toy-loc)
     (location:col  toy-loc)))

  ;; getType — mirrors MLIRGenImpl::getType(ArrayRef<int64_t>)
  ;; Build an MLIR tensor type from a list of dimension integers.
  (define (%%get-type shape)
    (if (null? shape)
        ;; empty shape → unranked tensor<*xf64>
        (mlir::UnrankedTensorType::get (mlir::Float64Type::get))
        ;; explicit shape → ranked tensor<d0xd1x...xf64>
        (mlir::RankedTensorType::get shape (mlir::Float64Type::get))))

  ;; collect-data — mirrors MLIRGenImpl::collectData()
  ;; Flatten a nested literal-expr tree into a list of f64 values.
  (define (%%collect-data expr)
    (cond
     [(literal-expr? expr)
      (apply append (map %%collect-data (literal-expr:values expr)))]
     [(number-expr? expr)
      (list (number-expr:val expr))]
     [else (error '%%collect-data "unexpected expr type" expr)]))

  ;; declare! — mirrors MLIRGenImpl::declare()
  ;; Add var→value to symbol table; error if already declared.
  (define (%%declare! symtab name value)
    (when (hashtable-ref symtab name #f)
      (error 'mlir-gen "variable already declared" name))
    (hashtable-set! symtab name value))

  ;; -------------------------------------------------------------------------
  ;; Op creation helpers
  ;; -------------------------------------------------------------------------

  ;; Create a single-result op with given operands, attributes, and result types.
  (define (%%create-op! builder loc name operands attrs result-types)
    (with-OperationState (state loc name)
                         (unless (null? operands)
                           (mlir::OperationState::addOperands state operands))
                         (for-each (lambda (kv)
                                     (mlir::OperationState::addAttribute state (car kv) (cdr kv)))
                                   attrs)
                         (unless (null? result-types)
                           (mlir::OperationState::addTypes state result-types))
                         (mlir::OpBuilder::create<OperationState> builder state)))

  (define (%%f64-unranked-tensor)
    (%%get-type '()))

  ;; -------------------------------------------------------------------------
  ;; Expression code generation
  ;; -------------------------------------------------------------------------

  ;; mlirGen(NumberExprAST) — scalar constant
  (define (%%mlir-gen-number builder expr)
    (let* ([loc  (%%loc (number-expr:loc expr))]
           [val  (number-expr:val expr)]
           [type (mlir::RankedTensorType::get '() (mlir::Float64Type::get))]
           [attr (mlir::DenseElementsAttr::get<f64> type (list val))])
      (mlir::Operation::getResult
       (%%create-op! builder loc "toy.constant" '()
                     (list (cons "value" attr))
                     (list type))
       0)))

  ;; mlirGen(LiteralExprAST) — tensor constant from dense data
  (define (%%mlir-gen-literal builder expr)
    (let* ([loc   (%%loc (literal-expr:loc expr))]
           [dims  (literal-expr:dims expr)]
           [data  (%%collect-data expr)]
           [type  (mlir::RankedTensorType::get dims (mlir::Float64Type::get))]
           [attr  (mlir::DenseElementsAttr::get<f64> type data)])
      (mlir::Operation::getResult
       (%%create-op! builder loc "toy.constant" '()
                     (list (cons "value" attr))
                     (list type))
       0)))

  ;; mlirGen(VariableExprAST) — symbol table lookup
  (define (%%mlir-gen-var symtab expr)
    (let ([val (hashtable-ref symtab (var-expr:name expr) #f)])
      (unless val
        (error 'mlir-gen "unknown variable" (var-expr:name expr)))
      val))

  ;; mlirGen(BinaryExprAST) — add or mul
  (define (%%mlir-gen-binary builder symtab expr)
    (let ([lhs (%%mlir-gen-expr builder symtab (binary-expr:lhs expr))]
          [rhs (%%mlir-gen-expr builder symtab (binary-expr:rhs expr))]
          [loc (%%loc (binary-expr:loc expr))])
      (let ([op-name (case (binary-expr:op expr)
                       [(#\+) "toy.add"]
                       [(#\*) "toy.mul"]
                       [else (error 'mlir-gen "unknown binary op" (binary-expr:op expr))])])
        (mlir::Operation::getResult
         (%%create-op! builder loc op-name (list lhs rhs)
                       '() (list (%%f64-unranked-tensor)))
         0))))

  ;; mlirGen(CallExprAST) — transpose, generic_call, or print
  (define (%%mlir-gen-call builder symtab expr)
    (let ([callee (call-expr:callee expr)]
          [loc    (%%loc (call-expr:loc expr))]
          [args   (map (lambda (a) (%%mlir-gen-expr builder symtab a))
                       (call-expr:args expr))])
      (cond
       [(string=? callee "transpose")
        (unless (= (length args) 1)
          (error 'mlir-gen "transpose takes exactly one argument"))
        (mlir::Operation::getResult
         (%%create-op! builder loc "toy.transpose" args
                       '() (list (%%f64-unranked-tensor)))
         0)]
       [else
        (let ([callee-attr (mlir::StringAttr::get (current-MLIRContext) callee)])
          (mlir::Operation::getResult
           (%%create-op! builder loc "toy.generic_call" args
                         (list (cons "callee" callee-attr))
                         (list (%%f64-unranked-tensor)))
           0))])))

  ;; mlirGen(PrintExprAST)
  (define (%%mlir-gen-print builder symtab expr)
    (let ([arg (%%mlir-gen-expr builder symtab (print-expr:arg expr))]
          [loc (%%loc (print-expr:loc expr))])
      (%%create-op! builder loc "toy.print" (list arg) '() '())))

  ;; mlirGen(ReturnExprAST)
  (define (%%mlir-gen-return builder symtab expr)
    (let ([loc (%%loc (return-expr:loc expr))]
          [val (and (return-expr:expr expr)
                    (%%mlir-gen-expr builder symtab (return-expr:expr expr)))])
      (%%create-op! builder loc "toy.return"
                    (if val (list val) '()) '() '())))

  ;; mlirGen(VarDeclExprAST)
  (define (%%mlir-gen-var-decl builder symtab expr)
    (let* ([init (%%mlir-gen-expr builder symtab (var-decl-expr:init-val expr))]
           [loc  (%%loc (var-decl-expr:loc expr))]
           [shape (var-type:shape (var-decl-expr:type expr))]
           [val   (if (null? shape)
                      init
                      (mlir::Operation::getResult
                       (%%create-op! builder loc "toy.reshape" (list init)
                                     '() (list (%%get-type shape)))
                       0))])
      (%%declare! symtab (var-decl-expr:name expr) val)
      val))

  ;; Dispatch on AST node type — mirrors MLIRGenImpl::mlirGen(ExprAST&)
  (define (%%mlir-gen-expr builder symtab expr)
    (cond
     [(number-expr?   expr) (%%mlir-gen-number  builder expr)]
     [(literal-expr?  expr) (%%mlir-gen-literal builder expr)]
     [(var-expr?      expr) (%%mlir-gen-var     symtab  expr)]
     [(binary-expr?   expr) (%%mlir-gen-binary  builder symtab expr)]
     [(call-expr?     expr) (%%mlir-gen-call    builder symtab expr)]
     [(print-expr?    expr) (%%mlir-gen-print   builder symtab expr)]
     [(return-expr?   expr) (%%mlir-gen-return  builder symtab expr)]
     [(var-decl-expr? expr) (%%mlir-gen-var-decl builder symtab expr)]
     [else (error 'mlir-gen "unhandled expression type" expr)]))

  ;; mlirGen(ExprASTList) — code-gen a block body
  (define (%%mlir-gen-block builder symtab stmts)
    (for-each (lambda (stmt) (%%mlir-gen-expr builder symtab stmt)) stmts))

  ;; -------------------------------------------------------------------------
  ;; Function code generation — mirrors MLIRGenImpl::mlirGen(FunctionAST&)
  ;; -------------------------------------------------------------------------
  (define (%%mlir-gen-function module-body symtab fn)
    (let* ([proto   (function:proto fn)]
           [body    (function:body  fn)]
           [loc     (%%loc (prototype:loc proto))]
           [name    (prototype:name proto)]
           [args    (prototype:args proto)]
           [n-args  (length args)]
           ;; All arguments are unranked tensor<*xf64>
           [arg-types (map (lambda (_) (%%f64-unranked-tensor)) args)]
           [func-type (mlir::FunctionType::get (current-MLIRContext)
                                               arg-types '())])
      ;; Create toy.func op
      (with-OperationState (state loc "toy.func")
                           (mlir::OperationState::addAttribute
                            state "sym_name"
                            (mlir::StringAttr::get (current-MLIRContext) name))
                           (mlir::OperationState::addAttribute
                            state "function_type"
                            (mlir::TypeAttr::get func-type))
                           ;; Add entry block with arguments
                           (let* ([region (mlir::OperationState::addRegion state)]
                                  [block  (mlir::Region::emplaceBlock region)])
                             (for-each (lambda (t) (mlir::Block::addArgument block t loc))
                                       arg-types)
                             ;; Build function body
                             (let ([fn-builder (mlir::OpBuilder::atBlockEnd block)])
                               ;; Bind argument names in symbol table
                               (for-each (lambda (arg-ast idx)
                                           (%%declare! symtab
                                                       (var-expr:name arg-ast)
                                                       (mlir::Block::getArgument block idx)))
                                         args
                                         (iota n-args))
                               ;; Codegen body
                               (%%mlir-gen-block fn-builder symtab body)
                               ;; Implicit return if block doesn't end with return
                               (when (or (mlir::Block::empty? block)
                                         (not (toy.return? (mlir::Block::back block))))
                                 (%%create-op! fn-builder loc "toy.return" '() '() '())))
                             (mlir::OpBuilder::create<OperationState>
                              (mlir::OpBuilder::atBlockEnd module-body) state)))))

  ;; -------------------------------------------------------------------------
  ;; Module code generation — public API
  ;; mirrors toy::mlirGen(MLIRContext&, ModuleAST&)
  ;; -------------------------------------------------------------------------
  (define (mlir-gen ctx module)
    (with-current-MLIRContext ctx
      (let* ([module-op   (mlir::ModuleOp::create
                           (mlir::UnknownLoc::get ctx))]
             [module-body (mlir::Block::front (mlir::ModuleOp::getBody module-op))])
        (for-each (lambda (fn)
                    (let ([symtab (make-equal-hashtable)])
                      (%%mlir-gen-function module-body symtab fn)))
                  (module-ast:functions module))
        module-op)))
  )

;; MLIR code generation from the Toy AST.
;; Mirrors mlir/examples/toy/Ch4/mlir/MLIRGen.cpp
;;
;; Ch4 adds private visibility to non-main functions so the inliner can
;; eliminate them after inlining all call sites.
(library (toy ch4 mlir-gen)
  (export mlir-gen)
  (import (except (chezscheme) =)
          (mlir IR MLIRContext)
          (mlir IR Builders)
          (mlir IR BuiltinTypes)
          (mlir IR BuiltinAttributes)
          (mlir IR Location)
          (mlir IR OperationSupport)
          (mlir IR Operation)
          (mlir IR Region)
          (mlir IR Block)
          (mlir IR BuiltinOps)
          (toy ch4 ast)
          (for (only (crest pattern-dsl rewrite) begin-mlir-code) expand)
          (for (only (crest pattern-dsl keywords) = :string :loc :builder :arg) expand)
          (only (crest pattern-dsl keywords) = : -> :region :loc
                :string :index :i8 :i16 :i32 :i64 :f32 :f64
                :i8-array :i16-array :i32-array :i64-array :unit))

  (define (toy.return? op)
    (string=? (mlir::Operation::getName op) "toy.return"))

  (define (%%loc toy-loc)
    (mlir::FileLineColLoc::get
     (current-MLIRContext)
     (location:file toy-loc)
     (location:line toy-loc)
     (location:col  toy-loc)))

  (define (%%get-type shape)
    (if (null? shape)
        (mlir::UnrankedTensorType::get (mlir::Float64Type::get))
        (mlir::RankedTensorType::get shape (mlir::Float64Type::get))))

  (define (%%collect-data expr)
    (cond
     [(literal-expr? expr)
      (apply append (map %%collect-data (literal-expr:values expr)))]
     [(number-expr? expr)
      (list (number-expr:val expr))]
     [else (error '%%collect-data "unexpected expr type" expr)]))

  (define (%%declare! symtab name value)
    (when (hashtable-ref symtab name #f)
      (error 'mlir-gen "variable already declared" name))
    (hashtable-set! symtab name value))

  (define (%%create-op! builder loc name operands attrs result-types)
    (with-OperationState (state loc name)
                         (for-each (lambda (v) (mlir::OperationState::addOperands state v))
                                   operands)
                         (for-each (lambda (kv)
                                     (mlir::OperationState::addAttribute state (car kv) (cdr kv)))
                                   attrs)
                         (for-each (lambda (t) (mlir::OperationState::addTypes state t))
                                   result-types)
                         (mlir::OpBuilder::create<OperationState> builder state)))

  (define (%%f64-unranked-tensor)
    (%%get-type '()))

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

  (define (%%mlir-gen-var symtab expr)
    (let ([val (hashtable-ref symtab (var-expr:name expr) #f)])
      (unless val
        (error 'mlir-gen "unknown variable" (var-expr:name expr)))
      val))

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

  (define (%%mlir-gen-call builder symtab expr)
    (let ([callee (call-expr:callee expr)]
          [loc    (%%loc (call-expr:loc expr))]
          [args   (map (lambda (a) (%%mlir-gen-expr builder symtab a))
                       (call-expr:args expr))])
      (cond
       [(string=? callee "transpose")
        (unless (fx=? (length args) 1)
          (error 'mlir-gen "transpose takes exactly one argument"))
        (mlir::Operation::getResult
         (%%create-op! builder loc "toy.transpose" args
                       '() (list (%%f64-unranked-tensor)))
         0)]
       [else
        (let ([callee-attr (mlir::StringAttr::get callee)])
          (mlir::Operation::getResult
           (%%create-op! builder loc "toy.generic_call" args
                         (list (cons "callee" callee-attr))
                         (list (%%f64-unranked-tensor)))
           0))])))

  (define (%%mlir-gen-print builder symtab expr)
    (let ([arg (%%mlir-gen-expr builder symtab (print-expr:arg expr))]
          [loc (%%loc (print-expr:loc expr))])
      (%%create-op! builder loc "toy.print" (list arg) '() '())))

  (define (%%mlir-gen-return builder symtab expr)
    (let ([loc (%%loc (return-expr:loc expr))]
          [val (and (return-expr:expr expr)
                    (%%mlir-gen-expr builder symtab (return-expr:expr expr)))])
      (%%create-op! builder loc "toy.return"
                    (if val (list val) '()) '() '())))

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

  (define (%%mlir-gen-block builder symtab stmts)
    (for-each (lambda (stmt) (%%mlir-gen-expr builder symtab stmt)) stmts))

  (define (%%mlir-gen-function module-body symtab fn)
    (let* ([proto     (function:proto fn)]
           [body      (function:body  fn)]
           [proto-loc (prototype:loc proto)]
           [name      (prototype:name proto)]
           [args      (prototype:args proto)]
           [arg-types (map (lambda (_) (%%f64-unranked-tensor)) args)]
           [func-type (mlir::FunctionType::get (current-MLIRContext) arg-types '())]
           [%%fn-bld  (mlir::OpBuilder::atBlockEnd module-body)])
      (let ([func-op
             (begin-mlir-code %%fn-bld
               toy.func ()
               (sym_name      : name :string)
               (function_type : (mlir::TypeAttr::get func-type))
               (^bb0 ,@arg-types
                     (for-each (lambda (arg-ast idx)
                                 (%%declare! symtab (var-expr:name arg-ast) (:arg idx)))
                               args (iota (length args)))
                     (%%mlir-gen-block :builder symtab body)
                     (when (or (mlir::Block::empty? (current-MLIRBlock))
                               (not (toy.return? (mlir::Block::back (current-MLIRBlock)))))
                       (%%create-op! :builder (%%loc proto-loc) "toy.return" '() '() '())))
               :loc ((location:file proto-loc)
                     (location:line proto-loc)
                     (location:col  proto-loc)))])
        ;; Non-main functions are private so the inliner can remove them
        ;; after all call sites are inlined.
        (unless (string=? name "main")
          (mlir::Operation::setAttr! func-op "sym_visibility"
                                     (mlir::StringAttr::get "private")))
        func-op)))

  (define (mlir-gen ctx module)
    (with-current-MLIRContext ctx
      (let* ([module-op   (mlir::ModuleOp::create
                           (mlir::UnknownLoc::get ctx))]
             [module-body (mlir::ModuleOp::getBody module-op)])
        (for-each (lambda (fn)
                    (let ([symtab (make-hashtable equal-hash equal?)])
                      (%%mlir-gen-function module-body symtab fn)))
                  (module-ast:functions module))
        module-op)))
  )

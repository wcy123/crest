;; MLIR code generation from the Toy AST.
;; Mirrors mlir/examples/toy/Ch4/mlir/MLIRGen.cpp
;;
;; Ch4 adds private visibility to non-main functions so the inliner can
;; eliminate them after inlining all call sites.
(library (toy ch6 mlir-gen)
  (export mlir-gen)
  (import (except (chezscheme) =)
          (mlir IR MLIRContext)
          (mlir IR Builders)
          (mlir IR BuiltinTypes)
          (mlir IR BuiltinAttributes)
          (mlir IR Location)
          (mlir IR Diagnostics)
          (mlir IR Operation)
          (mlir IR Region)
          (mlir IR Block)
          (mlir IR BuiltinOps)
          (toy ch6 ast)
          (for (only (crest pattern-dsl rewrite) begin-mlir-code) expand)
          (for (only (crest pattern-dsl keywords) = :string :loc :arg) expand)
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

  ;; Report an error at a location through the diagnostic engine and abandon code generation:
  ;; mlir-gen then returns #f, as the C++ MLIRGen returns a null module.
  (define (%%fail loc . parts)
    (mlir::emitError loc (apply string-append parts))
    (raise 'toy-mlir-gen-failed))

  (define (%%declare! loc symtab name value)
    (when (hashtable-ref symtab name #f)
      (%%fail loc "error: variable '" name "' is already declared"))
    (hashtable-set! symtab name value))

  (define (%%f64-unranked-tensor)
    (%%get-type '()))

  (define (%%mlir-gen-number expr)
    (let* ([loc  (%%loc (number-expr:loc expr))]
           [val  (number-expr:val expr)]
           [type (mlir::RankedTensorType::get '() (mlir::Float64Type::get))]
           [attr (mlir::DenseElementsAttr::get<f64> type (list val))])
      (begin-mlir-code
          r = toy.constant () (value : attr) :loc loc)))

  (define (%%mlir-gen-literal expr)
    (let* ([loc   (%%loc (literal-expr:loc expr))]
           [dims  (literal-expr:dims expr)]
           [data  (%%collect-data expr)]
           [type  (mlir::RankedTensorType::get dims (mlir::Float64Type::get))]
           [attr  (mlir::DenseElementsAttr::get<f64> type data)])
      (begin-mlir-code
          r = toy.constant () (value : attr) :loc loc)))

  (define (%%mlir-gen-var symtab expr)
    (let ([val (hashtable-ref symtab (var-expr:name expr) #f)])
      (unless val
        (%%fail (%%loc (var-expr:loc expr)) "error: unknown variable '" (var-expr:name expr) "'"))
      val))

  (define (%%mlir-gen-binary symtab expr)
    (let ([lhs (%%mlir-gen-expr symtab (binary-expr:lhs expr))]
          [rhs (%%mlir-gen-expr symtab (binary-expr:rhs expr))]
          [loc (%%loc (binary-expr:loc expr))])
      (case (binary-expr:op expr)
        [(#\+) (begin-mlir-code r = toy.add (lhs rhs) :loc loc)]
        [(#\*) (begin-mlir-code r = toy.mul (lhs rhs) :loc loc)]
        [else (%%fail (%%loc (binary-expr:loc expr)) "invalid binary operator '" (string (binary-expr:op expr)) "'")])))

  (define (%%mlir-gen-call symtab expr)
    (let ([callee (call-expr:callee expr)]
          [loc    (%%loc (call-expr:loc expr))]
          [args   (map (lambda (a) (%%mlir-gen-expr symtab a))
                       (call-expr:args expr))])
      (cond
       [(string=? callee "transpose")
        (unless (fx=? (length args) 1)
          (%%fail (%%loc (call-expr:loc expr)) "MLIR codegen encountered an error: toy.transpose does not accept multiple arguments"))
        (begin-mlir-code
            r = toy.transpose (,@args) :loc loc)]
       [else
        (let ([type (%%f64-unranked-tensor)])
          (begin-mlir-code
              r = toy.generic_call (,@args)
              (callee : (mlir::FlatSymbolRefAttr::get callee))
              :loc loc
              -> type))])))

  (define (%%mlir-gen-print symtab expr)
    (let ([arg (%%mlir-gen-expr symtab (print-expr:arg expr))]
          [loc (%%loc (print-expr:loc expr))])
      (begin-mlir-code
          toy.print (arg) :loc loc)))

  (define (%%mlir-gen-return symtab expr)
    (let ([loc (%%loc (return-expr:loc expr))]
          [val (and (return-expr:expr expr)
                    (%%mlir-gen-expr symtab (return-expr:expr expr)))])
      (begin-mlir-code
          toy.return (,@(if val (list val) '())) :loc loc)))

  (define (%%mlir-gen-var-decl symtab expr)
    (let* ([init (%%mlir-gen-expr symtab (var-decl-expr:init-val expr))]
           [loc  (%%loc (var-decl-expr:loc expr))]
           [shape (var-type:shape (var-decl-expr:type expr))]
           [val   (if (null? shape)
                      init
                      (let ([reshaped-type (%%get-type shape)])
                        (begin-mlir-code
                            r = toy.reshape (init) :loc loc -> reshaped-type)))])
      (%%declare! (%%loc (var-decl-expr:loc expr)) symtab (var-decl-expr:name expr) val)
      val))

  (define (%%mlir-gen-expr symtab expr)
    (cond
     [(number-expr?   expr) (%%mlir-gen-number  expr)]
     [(literal-expr?  expr) (%%mlir-gen-literal expr)]
     [(var-expr?      expr) (%%mlir-gen-var     symtab  expr)]
     [(binary-expr?   expr) (%%mlir-gen-binary  symtab expr)]
     [(call-expr?     expr) (%%mlir-gen-call    symtab expr)]
     [(print-expr?    expr) (%%mlir-gen-print   symtab expr)]
     [(return-expr?   expr) (%%mlir-gen-return  symtab expr)]
     [(var-decl-expr? expr) (%%mlir-gen-var-decl symtab expr)]
     [else (error 'mlir-gen "unhandled expression type" expr)]))

  (define (%%mlir-gen-block symtab stmts)
    (for-each (lambda (stmt) (%%mlir-gen-expr symtab stmt)) stmts))

  (define (%%mlir-gen-function module-body symtab fn)
    (let* ([proto     (function:proto fn)]
           [body      (function:body  fn)]
           [proto-loc (prototype:loc proto)]
           [name      (prototype:name proto)]
           [args      (prototype:args proto)]
           [arg-types (map (lambda (_) (%%f64-unranked-tensor)) args)]
           [func-type (mlir::FunctionType::get (current-MLIRContext) arg-types '())])
      ;; LEAK WARNING: atBlockEnd makes the builder on the C++ heap and only the caller frees it. A plain let
      ;; leaked it for every function; with-OpBuilder frees it when the function is done.
      (with-OpBuilder %%fn-bld (mlir::OpBuilder::atBlockEnd module-body)
        (let ([func-op
               (with-current-OpBuilder %%fn-bld
                 (begin-mlir-code
                     toy.func ()
                     (sym_name      : name :string)
                     (function_type : (mlir::TypeAttr::get func-type))
                     (^bb0 ,@arg-types
                           (for-each (lambda (arg-ast idx)
                                       (%%declare! (%%loc (var-expr:loc arg-ast)) symtab (var-expr:name arg-ast) (:arg idx)))
                                     args (iota (length args)))
                           (%%mlir-gen-block symtab body)
                           (when (or (mlir::Block::empty? (current-Block))
                                     (not (toy.return? (mlir::Block::back (current-Block)))))
                             (begin-mlir-code
                                 toy.return () :loc (%%loc proto-loc)))
                           ;; As C++ MLIRGen does: a function that returns a value has one
                           ;; unranked tensor result (shape inference refines it later).
                           (let ([ret (mlir::Block::back (current-Block))])
                             (when (> (mlir::Operation::getNumOperands ret) 0)
                               (mlir::Operation::setAttr!
                                (mlir::Operation::getParentOp ret) "function_type"
                                (mlir::TypeAttr::get
                                 (mlir::FunctionType::get (current-MLIRContext) arg-types
                                                          (list (%%f64-unranked-tensor))))))))
                     :loc ((location:file proto-loc)
                           (location:line proto-loc)
                           (location:col  proto-loc))))])
          ;; Non-main functions are private so the inliner can remove them
          ;; after all call sites are inlined.
          (unless (string=? name "main")
            (mlir::Operation::setAttr! func-op "sym_visibility"
                                       (mlir::StringAttr::get "private")))
          func-op))))

  (define (mlir-gen ctx module)
    ;; The module is erased when generation fails or raises: only a module that is returned
    ;; (verified) belongs to the caller, who erases it (with-mlir::OwningOpRef).
    (let ([created #f] [keep? #f])
      (dynamic-wind
          (lambda () #f)
          (lambda ()
            (let ([result (guard (e [(eq? e 'toy-mlir-gen-failed) #f])
                            (with-current-MLIRContext ctx
                              (let* ([module-op   (let ([m (mlir::ModuleOp::create
                                                            (mlir::UnknownLoc::get ctx))]) (set! created m) m)]
                                     [module-body (mlir::ModuleOp::getBody module-op)])
                                (for-each (lambda (fn)
                                            (let ([symtab (make-hashtable equal-hash equal?)])
                                              (%%mlir-gen-function module-body symtab fn)))
                                          (module-ast:functions module))
                                ;; As C++ MLIRGen: the module must verify.
                                (cond
                                 [(mlir::Operation::verify? (mlir::ModuleOp::getOperation module-op)) module-op]
                                 [else
                                  (mlir::Operation::emitError (mlir::ModuleOp::getOperation module-op)
                                                              "module verification error")
                                  #f]))))])
              (when result (set! keep? #t))
              result))
          (lambda ()
            (when (and created (not keep?))
              ;; once: a guard without a clause for an error leaves this extent twice
              (let ([module created])
                (set! created #f)
                (mlir::Operation::erase (mlir::ModuleOp::getOperation module))))))))
  )

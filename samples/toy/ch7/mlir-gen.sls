;; MLIR code generation from the Toy AST.
;; Mirrors mlir/examples/toy/Ch4/mlir/MLIRGen.cpp
;;
;; Ch4 adds private visibility to non-main functions so the inliner can
;; eliminate them after inlining all call sites.
(library (toy ch7 mlir-gen)
  (export mlir-gen)
  (import (except (chezscheme) =)
          (mlir IR MLIRContext)
          (mlir IR Builders)
          (mlir IR BuiltinTypes)
          (mlir IR BuiltinAttributes)
          (mlir IR Location)
          (mlir IR Operation)
          (mlir IR Region)
          (mlir IR Block)
          (mlir IR BuiltinOps)
          (only (mlir IR Value) mlir::Value::getType)
          (mlir Dialect Toy ToyStructType)
          (toy ch7 ast)
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

  (define (%%declare! symtab name value)
    (when (hashtable-ref symtab name #f)
      (error 'mlir-gen "variable already declared" name))
    (hashtable-set! symtab name value))

  (define (%%f64-unranked-tensor)
    (%%get-type '()))

  (define (%%mlir-gen-number expr)
    (let* ([loc  (%%loc (number-expr:loc expr))]
           [val  (number-expr:val expr)]
           [type (mlir::RankedTensorType::get '() (mlir::Float64Type::get))]
           [attr (mlir::DenseElementsAttr::get<f64> type (list val))])
      (begin-mlir-code
          r = toy.constant () (value : attr) :loc loc -> type)))

  (define (%%mlir-gen-literal expr)
    (let* ([loc   (%%loc (literal-expr:loc expr))]
           [dims  (literal-expr:dims expr)]
           [data  (%%collect-data expr)]
           [type  (mlir::RankedTensorType::get dims (mlir::Float64Type::get))]
           [attr  (mlir::DenseElementsAttr::get<f64> type data)])
      (begin-mlir-code
          r = toy.constant () (value : attr) :loc loc -> type)))

  (define (%%mlir-gen-var symtab expr)
    (let ([val (hashtable-ref symtab (var-expr:name expr) #f)])
      (unless val
        (error 'mlir-gen "unknown variable" (var-expr:name expr)))
      val))

  ;; Compute the MLIR type for a var-decl: if the var-type has a struct name,
  ;; look it up in struct-map; otherwise use the unranked tensor.
  (define (%%get-var-type var-t struct-map)
    (let ([shape (var-type:shape var-t)])
      (if (and (pair? shape) (string? (car shape)))
          ;; struct-typed
          (let ([entry (hashtable-ref struct-map (car shape) #f)])
            (if entry (car entry) (%%f64-unranked-tensor)))
          ;; tensor-typed
          (%%get-type shape))))

  (define (%%mlir-gen-struct-attr struct-map expr)
    ;; Build a (ArrayAttr, StructType) pair for a struct literal
    (let loop ([values (struct-literal-expr:values expr)]
               [attrs '()]
               [types '()])
      (if (null? values)
          (let* ([arr  (mlir::ArrayAttr::get (current-MLIRContext) attrs)]
                 [stype (toy::StructType::get types)])
            (cons arr stype))
          (let ([v (car values)])
            (cond
             [(literal-expr? v)
              ;; tensor literal → DenseElementsAttr
              (let* ([dims  (literal-expr:dims v)]
                     [data  (%%collect-data v)]
                     [type  (mlir::RankedTensorType::get dims (mlir::Float64Type::get))]
                     [attr  (mlir::DenseElementsAttr::get<f64> type data)])
                (loop (cdr values)
                      (append attrs (list attr))
                      (append types (list type))))]
             [(struct-literal-expr? v)
              (let* ([pair  (%%mlir-gen-struct-attr struct-map v)]
                     [attr  (car pair)]
                     [stype (cdr pair)])
                (loop (cdr values)
                      (append attrs (list attr))
                      (append types (list stype))))]
             [else
              (error '%%mlir-gen-struct-attr "unexpected struct field value" v)])))))

  (define (%%mlir-gen-binary symtab struct-map expr)
    (let ([loc (%%loc (binary-expr:loc expr))]
          [op  (binary-expr:op expr)])
      (if (char=? op #\.)
          ;; struct field access: lhs.rhs-as-field-name
          (let* ([lhs (%%mlir-gen-expr symtab struct-map (binary-expr:lhs expr))]
                 [rhs (binary-expr:rhs expr)]
                 [field-name (if (var-expr? rhs) (var-expr:name rhs)
                                 (error 'mlir-gen "struct access requires identifier" rhs))]
                 ;; find field index from struct type
                 [lhs-type   (mlir::Value::getType lhs)]
                 [elem-types (if (toy::StructType? lhs-type)
                                 (toy::StructType::getElementTypes lhs-type)
                                 (error 'mlir-gen "dot operator on non-struct" lhs-type))]
                 ;; find the struct definition to get field names
                 [struct-decl (%%find-struct-decl-by-type struct-map lhs-type)]
                 [field-idx   (if struct-decl
                                  (%%find-field-index struct-decl field-name)
                                  (error 'mlir-gen "cannot find struct for field access" field-name))]
                 [result-type (list-ref elem-types field-idx)])
            (begin-mlir-code
                r = toy.struct_access (lhs)
                (index : field-idx :i64)
                :loc loc
                -> result-type))
          ;; regular binary op
          (let ([lhs (%%mlir-gen-expr symtab struct-map (binary-expr:lhs expr))]
                [rhs (%%mlir-gen-expr symtab struct-map (binary-expr:rhs expr))])
            (let ([type (%%f64-unranked-tensor)])
              (case op
                [(#\+) (begin-mlir-code r = toy.add (lhs rhs) :loc loc -> type)]
                [(#\*) (begin-mlir-code r = toy.mul (lhs rhs) :loc loc -> type)]
                [else (error 'mlir-gen "unknown binary op" op)]))))))


  (define (%%find-struct-decl-by-type struct-map stype)
    ;; Walk all entries and find the one whose StructType matches
    (call-with-current-continuation
     (lambda (return)
       (let ([keys (hashtable-keys   struct-map)]
             [vals (hashtable-values struct-map)])
         (vector-for-each (lambda (name pair)
                            (when (equal? (car pair) stype)
                              (return (cdr pair))))
                          keys vals))
       #f)))

  (define (%%find-field-index struct-decl field-name)
    (let loop ([vars (struct-ast:variables struct-decl)] [i 0])
      (if (null? vars)
          (error 'mlir-gen "field not found in struct" field-name)
          (if (string=? (var-decl-expr:name (car vars)) field-name)
              i
              (loop (cdr vars) (+ i 1))))))

  (define (%%mlir-gen-print symtab struct-map expr)
    (let ([arg (%%mlir-gen-expr symtab struct-map (print-expr:arg expr))]
          [loc (%%loc (print-expr:loc expr))])
      (begin-mlir-code
          toy.print (arg) :loc loc)))

  (define (%%mlir-gen-return symtab struct-map expr)
    (let ([loc (%%loc (return-expr:loc expr))]
          [val (and (return-expr:expr expr)
                    (%%mlir-gen-expr symtab struct-map (return-expr:expr expr)))])
      (begin-mlir-code
          toy.return (,@(if val (list val) '())) :loc loc)))

  (define (%%mlir-gen-var-decl symtab struct-map expr)
    (let* ([init   (%%mlir-gen-expr symtab struct-map (var-decl-expr:init-val expr))]
           [loc    (%%loc (var-decl-expr:loc expr))]
           [vtype  (var-decl-expr:type expr)]
           [shape  (var-type:shape vtype)]
           [val    (cond
                    ;; struct-typed — no reshape
                    [(and (pair? shape) (string? (car shape)))
                     init]
                    [(null? shape)
                     init]
                    [else
                     (let ([reshaped-type (%%get-type shape)])
                       (begin-mlir-code
                           r = toy.reshape (init) :loc loc -> reshaped-type))])])
      (%%declare! symtab (var-decl-expr:name expr) val)
      val))

  (define (%%mlir-gen-struct-literal struct-map expr)
    (let* ([loc  (%%loc (struct-literal-expr:loc expr))]
           [pair (%%mlir-gen-struct-attr struct-map expr)]
           [arr  (car pair)]
           [stype (cdr pair)])
      (begin-mlir-code
          r = toy.struct_constant () (value : arr) :loc loc -> stype)))

  (define (%%mlir-gen-expr symtab struct-map expr)
    (cond
     [(number-expr?        expr) (%%mlir-gen-number         expr)]
     [(literal-expr?       expr) (%%mlir-gen-literal        expr)]
     [(struct-literal-expr? expr) (%%mlir-gen-struct-literal struct-map expr)]
     [(var-expr?           expr) (%%mlir-gen-var            symtab  expr)]
     [(binary-expr?        expr) (%%mlir-gen-binary         symtab struct-map expr)]
     [(call-expr?          expr) (%%mlir-gen-call           symtab struct-map expr)]
     [(print-expr?         expr) (%%mlir-gen-print          symtab struct-map expr)]
     [(return-expr?        expr) (%%mlir-gen-return         symtab struct-map expr)]
     [(var-decl-expr? expr) (%%mlir-gen-var-decl symtab struct-map expr)]
     [else (error 'mlir-gen "unhandled expression type" expr)]))

  (define (%%mlir-gen-block symtab struct-map stmts)
    (for-each (lambda (stmt) (%%mlir-gen-expr symtab struct-map stmt)) stmts))

  (define (%%mlir-gen-call symtab struct-map expr)
    (let ([callee (call-expr:callee expr)]
          [loc    (%%loc (call-expr:loc expr))]
          [args   (map (lambda (a) (%%mlir-gen-expr symtab struct-map a))
                       (call-expr:args expr))])
      (cond
       [(string=? callee "transpose")
        (unless (fx=? (length args) 1)
          (error 'mlir-gen "transpose takes exactly one argument"))
        (let ([type (%%f64-unranked-tensor)])
          (begin-mlir-code
              r = toy.transpose (,@args) :loc loc -> type))]
       [else
        (let ([type (%%f64-unranked-tensor)])
          (begin-mlir-code
              r = toy.generic_call (,@args)
              (callee : callee :string)
              :loc loc
              -> type))])))

  (define (%%mlir-gen-function module-body symtab struct-map fn)
    (let* ([proto     (function:proto fn)]
           [body      (function:body  fn)]
           [proto-loc (prototype:loc proto)]
           [name      (prototype:name proto)]
           [args      (prototype:args proto)]
           [arg-types (map (lambda (a)
                             (if (var-decl-expr? a)
                                 (%%get-var-type (var-decl-expr:type a) struct-map)
                                 (%%f64-unranked-tensor)))
                           args)]
           [func-type (mlir::FunctionType::get (current-MLIRContext) arg-types '())]
           [%%fn-bld  (mlir::OpBuilder::atBlockEnd module-body)])
      (let ([func-op
             (with-current-OpBuilder %%fn-bld
               (begin-mlir-code
                   toy.func ()
                   (sym_name      : name :string)
                   (function_type : (mlir::TypeAttr::get func-type))
                   (^bb0 ,@arg-types
                         (for-each (lambda (arg-ast idx)
                                     (let ([arg-name (if (var-decl-expr? arg-ast)
                                                         (var-decl-expr:name arg-ast)
                                                         (var-expr:name arg-ast))])
                                       (%%declare! symtab arg-name (:arg idx))))
                                   args (iota (length args)))
                         (%%mlir-gen-block symtab struct-map body)
                         (when (or (mlir::Block::empty? (current-Block))
                                   (not (toy.return? (mlir::Block::back (current-Block)))))
                           (begin-mlir-code
                               toy.return () :loc (%%loc proto-loc))))
                   :loc ((location:file proto-loc)
                         (location:line proto-loc)
                         (location:col  proto-loc))))])
        (unless (string=? name "main")
          (mlir::Operation::setAttr! func-op "sym_visibility"
                                     (mlir::StringAttr::get "private")))
        func-op)))

  (define (%%mlir-gen-struct struct-map s)
    ;; Register a StructType for the named struct
    (let* ([vars  (struct-ast:variables s)]
           [types (map (lambda (v)
                         (let ([vt (var-decl-expr:type v)])
                           (let ([shape (var-type:shape vt)])
                             (if (and (pair? shape) (string? (car shape)))
                                 ;; nested struct type
                                 (let ([entry (hashtable-ref struct-map (car shape) #f)])
                                   (if entry (car entry) (%%f64-unranked-tensor)))
                                 (%%f64-unranked-tensor)))))
                       vars)])
      (let ([stype (toy::StructType::get types)])
        (hashtable-set! struct-map (struct-ast:name s) (cons stype s)))))

  (define (mlir-gen ctx module)
    (with-current-MLIRContext ctx
      (let* ([module-op   (mlir::ModuleOp::create (mlir::UnknownLoc::get ctx))]
             [module-body (mlir::ModuleOp::getBody module-op)]
             [struct-map  (make-hashtable equal-hash equal?)])
        ;; Register struct types first
        (for-each (lambda (s) (%%mlir-gen-struct struct-map s))
                  (module-ast:structs module))
        ;; Generate function bodies
        (for-each (lambda (fn)
                    (let ([symtab (make-hashtable equal-hash equal?)])
                      (%%mlir-gen-function module-body symtab struct-map fn)))
                  (module-ast:functions module))
        module-op)))
  )

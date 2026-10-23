;; AST node types and dumper for the Toy language.
;; Mirrors mlir/examples/toy/Ch1/include/toy/AST.h
;;         mlir/examples/toy/Ch1/parser/AST.cpp
(library (toy ch3 ast)
  (export
    ;; Location
    make-location   location?   location:file location:line location:col
    ;; VarType — shape is a list of exact integers
    make-var-type   var-type?   var-type:shape
    ;; Expressions (all carry a loc field)
    make-number-expr    number-expr?    number-expr:loc    number-expr:val
    make-literal-expr   literal-expr?   literal-expr:loc   literal-expr:values  literal-expr:dims
    make-var-expr       var-expr?       var-expr:loc       var-expr:name
    make-var-decl-expr  var-decl-expr?  var-decl-expr:loc  var-decl-expr:name
    var-decl-expr:type var-decl-expr:init-val
    make-return-expr    return-expr?    return-expr:loc    return-expr:expr
    make-binary-expr    binary-expr?    binary-expr:loc    binary-expr:op
    binary-expr:lhs    binary-expr:rhs
    make-call-expr      call-expr?      call-expr:loc      call-expr:callee  call-expr:args
    make-print-expr     print-expr?     print-expr:loc     print-expr:arg
    ;; Top-level
    make-prototype  prototype?  prototype:loc  prototype:name  prototype:args
    make-function   function?   function:proto function:body
    make-module-ast     module-ast?     module-ast:functions
    ;; Dump — mirrors toy::dump(ModuleAST&) in AST.cpp
    toy:dump)
  (import (chezscheme))

  (define-record-type location
    (fields (immutable file location:file)
            (immutable line location:line)
            (immutable col  location:col)))

  (define-record-type var-type
    (fields (immutable shape var-type:shape)))

  (define-record-type number-expr
    (fields (immutable loc number-expr:loc)
            (immutable val number-expr:val)))

  (define-record-type literal-expr
    (fields (immutable loc    literal-expr:loc)
            (immutable values literal-expr:values)  ; list of exprs
            (immutable dims   literal-expr:dims)))   ; list of ints

  (define-record-type var-expr
    (fields (immutable loc  var-expr:loc)
            (immutable name var-expr:name)))

  (define-record-type var-decl-expr
    (fields (immutable loc      var-decl-expr:loc)
            (immutable name     var-decl-expr:name)
            (immutable type     var-decl-expr:type)      ; var-type
            (immutable init-val var-decl-expr:init-val))) ; expr

  (define-record-type return-expr
    (fields (immutable loc  return-expr:loc)
            (immutable expr return-expr:expr)))  ; expr or #f

  (define-record-type binary-expr
    (fields (immutable loc binary-expr:loc)
            (immutable op  binary-expr:op)    ; character
            (immutable lhs binary-expr:lhs)
            (immutable rhs binary-expr:rhs)))

  (define-record-type call-expr
    (fields (immutable loc    call-expr:loc)
            (immutable callee call-expr:callee)  ; string
            (immutable args   call-expr:args)))  ; list of exprs

  (define-record-type print-expr
    (fields (immutable loc print-expr:loc)
            (immutable arg print-expr:arg)))

  (define-record-type prototype
    (fields (immutable loc  prototype:loc)
            (immutable name prototype:name)   ; string
            (immutable args prototype:args))) ; list of var-expr

  (define-record-type function
    (fields (immutable proto function:proto)  ; prototype
            (immutable body  function:body))) ; list of exprs

  (define-record-type module-ast
    (fields (immutable functions module-ast:functions))) ; list of function

  ;; -------------------------------------------------------------------------
  ;; ASTDumper — mirrors ASTDumper in parser/AST.cpp
  ;; curIndent is a parameter so it is dynamically scoped across recursion.
  ;; -------------------------------------------------------------------------

  (define %%cur-indent (make-parameter 0))

  (define (%%indent!)
    (let loop ([i (%%cur-indent)])
      (unless (= i 0) (display "  ") (loop (- i 1)))))

  ;; INDENT() macro: increment level, print leading spaces.
  (define-syntax %%INDENT
    (syntax-rules ()
      [(_ body ...)
       (parameterize ([%%cur-indent (+ (%%cur-indent) 1)])
         (%%indent!)
         body ...)]))

  (define (%%loc node-loc)
    (string-append "@" (location:file node-loc)
                   ":" (number->string (location:line node-loc))
                   ":" (number->string (location:col  node-loc))))

  ;; Dispatch to the correct dump overload by record type.
  (define (%%dump-expr expr)
    (cond
     [(number-expr?   expr) (%%dump-number   expr)]
     [(literal-expr?  expr) (%%dump-literal  expr)]
     [(var-expr?      expr) (%%dump-var      expr)]
     [(var-decl-expr? expr) (%%dump-var-decl expr)]
     [(return-expr?   expr) (%%dump-return   expr)]
     [(binary-expr?   expr) (%%dump-binary   expr)]
     [(call-expr?     expr) (%%dump-call     expr)]
     [(print-expr?    expr) (%%dump-print    expr)]
     [else (%%INDENT (display "<unknown expr>\n"))]))

  (define (%%dump-number node)
    (%%INDENT (display (number-expr:val node))
              (display " ")
              (display (%%loc (number-expr:loc node)))
              (display "\n")))

  ;; printLitHelper — recursive helper for nested array literals
  (define (%%lit-helper expr)
    (cond
     [(number-expr? expr)
      (display (number-expr:val expr))]
     [(literal-expr? expr)
      (display "<")
      (let loop ([dims (literal-expr:dims expr)] [first #t])
        (unless (null? dims)
          (unless first (display ","))
          (display (car dims))
          (loop (cdr dims) #f)))
      (display ">[ ")
      (let loop ([vals (literal-expr:values expr)] [first #t])
        (unless (null? vals)
          (unless first (display ", "))
          (%%lit-helper (car vals))
          (loop (cdr vals) #f)))
      (display "]")]))

  (define (%%dump-literal node)
    (%%INDENT (display "Literal: ")
              (%%lit-helper node)
              (display " ")
              (display (%%loc (literal-expr:loc node)))
              (display "\n")))

  (define (%%dump-var node)
    (%%INDENT (display "var: ")
              (display (var-expr:name node))
              (display " ")
              (display (%%loc (var-expr:loc node)))
              (display "\n")))

  (define (%%dump-var-type type)
    (display "<")
    (let loop ([shape (var-type:shape type)] [first #t])
      (unless (null? shape)
        (unless first (display ","))
        (display (car shape))
        (loop (cdr shape) #f)))
    (display ">"))

  (define (%%dump-var-decl node)
    (%%INDENT (display "VarDecl ")
              (display (var-decl-expr:name node))
              (%%dump-var-type (var-decl-expr:type node))
              (display " ")
              (display (%%loc (var-decl-expr:loc node)))
              (display "\n")
              (%%dump-expr (var-decl-expr:init-val node))))

  (define (%%dump-block exprs)
    (%%INDENT (display "Block {\n")
              (for-each %%dump-expr exprs)
              (%%indent!)
              (display "} // Block\n")))

  (define (%%dump-return node)
    (%%INDENT (display "Return\n")
              (if (return-expr:expr node)
                  (%%dump-expr (return-expr:expr node))
                  (%%INDENT (display "(void)\n")))))

  (define (%%dump-binary node)
    (%%INDENT (display "BinOp: ")
              (display (binary-expr:op node))
              (display " ")
              (display (%%loc (binary-expr:loc node)))
              (display "\n")
              (%%dump-expr (binary-expr:lhs node))
              (%%dump-expr (binary-expr:rhs node))))

  (define (%%dump-call node)
    (%%INDENT (display "Call '")
              (display (call-expr:callee node))
              (display "' [ ")
              (display (%%loc (call-expr:loc node)))
              (display "\n")
              (for-each %%dump-expr (call-expr:args node))
              (%%indent!)
              (display "]\n")))

  (define (%%dump-print node)
    (%%INDENT (display "Print [ ")
              (display (%%loc (print-expr:loc node)))
              (display "\n")
              (%%dump-expr (print-expr:arg node))
              (%%indent!)
              (display "]\n")))

  (define (%%dump-proto node)
    (%%INDENT (display "Proto '")
              (display (prototype:name node))
              (display "' ")
              (display (%%loc (prototype:loc node)))
              (display "\n")
              (%%indent!)
              (display "Params: [")
              (let loop ([args (prototype:args node)] [first #t])
                (unless (null? args)
                  (unless first (display ", "))
                  (display (var-expr:name (car args)))
                  (loop (cdr args) #f)))
              (display "]\n")))

  (define (%%dump-function node)
    (%%INDENT (display "Function \n")
              (%%dump-proto (function:proto node))
              (%%dump-block (function:body  node))))

  (define (%%dump-module node)
    (%%INDENT (display "Module:\n")
              (for-each %%dump-function (module-ast:functions node))))

  (define (toy:dump mod)
    (parameterize ([%%cur-indent 0])
      (%%dump-module mod)))
  )
